import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/export/image_exporter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const TextStyle textStyle = TextStyle(height: 1);

/// Checks the invariants every [ExportStats] must satisfy for [result].
void expectConsistentStats(ChatImageEditorResult result, Uint8List source) {
  expect(result.stats, isNotNull);
  final stats = result.stats!;
  expect(stats.sourceByteLength, source.length);
  expect(stats.outputByteLength, result.bytes.length);
  expect(stats.outputWidth, result.width);
  expect(stats.outputHeight, result.height);
  expect(stats.encodeAttempts, greaterThanOrEqualTo(1));

  for (final part in <Duration>[
    stats.decodeTime,
    stats.renderTime,
    stats.encodeTime,
    stats.totalTime,
  ]) {
    expect(part, greaterThanOrEqualTo(Duration.zero));
    expect(stats.totalTime, greaterThanOrEqualTo(part));
  }
  // The phases run one after another inside the total.
  expect(
    stats.totalTime,
    greaterThanOrEqualTo(
      stats.decodeTime + stats.renderTime + stats.encodeTime,
    ),
  );
}

void main() {
  final source = noisyPng(64, 48);

  Future<ChatImageEditorResult> export({
    ExportOptions options = const ExportOptions(),
    ImageEditValue value = ImageEditValue.empty,
    int quality = 90,
  }) {
    return ImageExporter.export(
      bytes: source,
      originalSize: const Size(64, 48),
      value: value,
      options: options,
      textStyle: textStyle,
      quality: quality,
    );
  }

  group('ExportStats from an export', () {
    test('describe a plain JPEG export', () async {
      final result = await export(quality: 75);
      expectConsistentStats(result, source);
      expect(result.stats!.encodeAttempts, 1);
      expect(result.stats!.finalQuality, 75);
      expect(result.stats!.outputWidth, 64);
      expect(result.stats!.outputHeight, 48);
    });

    test('follow crop and maxLongEdge', () async {
      final result = await export(
        options: const ExportOptions(maxLongEdge: 20),
        value: const ImageEditValue(
          quarterTurns: 1,
          crop: Rect.fromLTRB(0, 0, 1, 0.5),
        ),
      );
      expectConsistentStats(result, source);
      // Turned: 48×64; the crop keeps the top half (48×32), capped to 20.
      expect(result.stats!.outputWidth, 20);
      expect(result.stats!.outputHeight, 13);
    });

    test('have no quality for PNG', () async {
      final result = await export(
        options: const ExportOptions(format: ExportFormat.png),
      );
      expectConsistentStats(result, source);
      expect(result.stats!.finalQuality, isNull);
      expect(result.stats!.encodeAttempts, 1);
    });

    test('count one attempt for PNG over maxBytes', () async {
      final result = await export(
        options: const ExportOptions(format: ExportFormat.png, maxBytes: 1),
      );
      expectConsistentStats(result, source);
      expect(result.exceedsMaxBytes, isTrue);
      expect(result.stats!.encodeAttempts, 1);
      expect(result.stats!.finalQuality, isNull);
    });

    test('count every attempt of the maxBytes ladder', () async {
      final encoder = FakeEncoder();
      final result = await export(
        // 100 bytes per quality point: 90, 80, 70, 60 are too big, 50 fits.
        options: ExportOptions(maxBytes: 5000, encoder: encoder),
      );
      expectConsistentStats(result, source);
      expect(encoder.qualities, <int>[90, 80, 70, 60, 50]);
      expect(result.exceedsMaxBytes, isFalse);
      expect(result.stats!.encodeAttempts, 5);
      expect(result.stats!.finalQuality, 50);
      expect(result.stats!.outputByteLength, 5000);
    });

    test('report the smallest attempt when nothing fits', () async {
      final encoder = FakeEncoder();
      final result = await export(
        options: ExportOptions(maxBytes: 10, minQuality: 60, encoder: encoder),
      );
      expectConsistentStats(result, source);
      expect(result.exceedsMaxBytes, isTrue);
      expect(result.stats!.encodeAttempts, 4);
      expect(result.stats!.finalQuality, 60);
      expect(result.stats!.outputByteLength, 6000);
    });

    test('count real encoder attempts when the ladder runs', () async {
      final first = await export();
      final encoder = CountingEncoder();
      final result = await export(
        options: ExportOptions(
          maxBytes: first.bytes.length - 1,
          encoder: encoder,
        ),
      );
      expectConsistentStats(result, source);
      expect(result.stats!.encodeAttempts, greaterThan(1));
      expect(result.stats!.encodeAttempts, encoder.calls);
      expect(result.stats!.finalQuality, lessThan(90));
    });
  });

  group('ExportStats', () {
    const stats = ExportStats(
      decodeTime: Duration(milliseconds: 1),
      renderTime: Duration(milliseconds: 2),
      encodeTime: Duration(milliseconds: 3),
      totalTime: Duration(milliseconds: 7),
      encodeAttempts: 2,
      finalQuality: 80,
      sourceByteLength: 1000,
      outputByteLength: 500,
      outputWidth: 40,
      outputHeight: 30,
    );

    test('compare by value', () {
      const same = ExportStats(
        decodeTime: Duration(milliseconds: 1),
        renderTime: Duration(milliseconds: 2),
        encodeTime: Duration(milliseconds: 3),
        totalTime: Duration(milliseconds: 7),
        encodeAttempts: 2,
        finalQuality: 80,
        sourceByteLength: 1000,
        outputByteLength: 500,
        outputWidth: 40,
        outputHeight: 30,
      );
      const png = ExportStats(
        decodeTime: Duration(milliseconds: 1),
        renderTime: Duration(milliseconds: 2),
        encodeTime: Duration(milliseconds: 3),
        totalTime: Duration(milliseconds: 7),
        encodeAttempts: 2,
        sourceByteLength: 1000,
        outputByteLength: 500,
        outputWidth: 40,
        outputHeight: 30,
      );
      expect(same, stats);
      expect(same.hashCode, stats.hashCode);
      expect(png, isNot(stats));
      expect(png.finalQuality, isNull);
    });

    test('describe themselves for logs', () {
      final text = stats.toString();
      expect(text, contains('total: 7.0 ms'));
      expect(text, contains('attempts: 2'));
      expect(text, contains('quality: 80'));
      expect(text, contains('1000 -> 500'));
      expect(text, contains('40x30'));
    });

    test('default to null on a hand-built result', () {
      final result = ChatImageEditorResult(
        bytes: Uint8List(0),
        width: 1,
        height: 1,
        format: ExportFormat.jpeg,
        edits: ImageEditValue.empty,
      );
      expect(result.stats, isNull);
    });
  });
}
