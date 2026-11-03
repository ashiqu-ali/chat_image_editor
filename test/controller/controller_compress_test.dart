import 'dart:async';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';
import 'controller_helpers.dart';

void main() {
  test('quality defaults to the export quality', () async {
    final controller = await loadedController(
      config: const ChatImageEditorConfig(export: ExportOptions(quality: 77)),
    );
    expect(controller.quality, 77);
    expect(controller.value.quality, isNull);
  });

  test('setQuality is live, clamped and records no history', () async {
    final controller = await loadedController();
    controller.selectTool(EditorTool.compress);
    expect(notificationsDuring(controller, () => controller.setQuality(50)), 1);
    expect(controller.quality, 50);
    expect(notificationsDuring(controller, () => controller.setQuality(50)), 0);
    controller.setQuality(500);
    expect(controller.quality, 100);
    controller.setQuality(-3);
    expect(controller.quality, 1);
  });

  test('commitQuality records one entry only when changed', () async {
    final controller = await loadedController();
    controller
      ..selectTool(EditorTool.compress)
      ..setQuality(60)
      ..setQuality(40);
    expect(notificationsDuring(controller, controller.commitQuality), 1);
    expect(notificationsDuring(controller, controller.commitQuality), 0);
    controller.closeTool();
    controller.undo();
    expect(controller.value.quality, isNull);
    expect(controller.canUndo, isFalse);
  });

  for (final exit in <String, void Function(ChatImageEditorController)>{
    'closeTool': (ChatImageEditorController c) => c.closeTool(),
    'selecting compress again': (ChatImageEditorController c) =>
        c.selectTool(EditorTool.compress),
    'selecting another tool': (ChatImageEditorController c) =>
        c.selectTool(EditorTool.draw),
  }.entries) {
    test('${exit.key} commits the quality change', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.compress)
        ..setQuality(30);
      expect(notificationsDuring(controller, () => exit.value(controller)), 1);
      expect(controller.value.quality, 30);
      controller.undo();
      expect(controller.value.quality, isNull);
      controller.redo();
      expect(controller.value.quality, 30);
    });
  }

  group('estimateSize', () {
    test('is null before an image is loaded', () async {
      final controller = ChatImageEditorController();
      addTearDown(controller.dispose);
      expect(await controller.estimateSize(80), isNull);
    });

    test('matches what export produces at that quality', () async {
      final controller = await loadedController(
        bytes: noisyPng(48, 32),
        config: const ChatImageEditorConfig(
          export: ExportOptions(maxLongEdge: null),
        ),
      );
      final estimate = await controller.estimateSize(70);
      controller
        ..selectTool(EditorTool.compress)
        ..setQuality(70)
        ..closeTool();
      final result = await controller.export();
      expect(estimate, result!.bytes.length);
    });

    test('lower quality estimates smaller files', () async {
      final controller = await loadedController(bytes: noisyPng(64, 64));
      final high = await controller.estimateSize(95);
      final low = await controller.estimateSize(20);
      expect(low, lessThan(high!));
    });

    test('is cached per edit state and quality', () async {
      final encoder = CountingEncoder();
      final controller = await loadedController(
        config: ChatImageEditorConfig(export: ExportOptions(encoder: encoder)),
      );
      final first = controller.estimateSize(60);
      expect(controller.estimateSize(60), same(first));
      await first;
      await controller.estimateSize(60);
      expect(encoder.calls, 1);

      await controller.estimateSize(40);
      expect(encoder.calls, 2);

      // The slider changing the picked quality doesn't invalidate it.
      controller
        ..selectTool(EditorTool.compress)
        ..setQuality(10);
      await controller.estimateSize(60);
      expect(encoder.calls, 2);

      // A new edit does.
      controller
        ..closeTool()
        ..rotateRight();
      await controller.estimateSize(60);
      expect(encoder.calls, 3);
    });

    test('encodes one quality at a time', () async {
      final encoder = _GatedEncoder();
      final controller = await loadedController(
        config: ChatImageEditorConfig(export: ExportOptions(encoder: encoder)),
      );
      final estimates = <Future<int?>>[
        for (final quality in <int>[80, 60, 40, 20])
          controller.estimateSize(quality),
      ];

      for (var i = 0; i < estimates.length; i++) {
        await encoder.waitForCalls(i + 1);
        // Give a wrongly started next encode the chance to show up.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(encoder.calls, i + 1);
        expect(encoder.active, 1);
        encoder.releaseNext();
      }

      expect(await Future.wait(estimates), <int?>[80, 60, 40, 20]);
      expect(encoder.maxActive, 1);
      expect(encoder.qualities, <int>[80, 60, 40, 20]);
    });

    test('a failed estimate does not block the next one', () async {
      final encoder = _GatedEncoder(failFirst: true);
      final controller = await loadedController(
        config: ChatImageEditorConfig(export: ExportOptions(encoder: encoder)),
      );
      final failed = controller.estimateSize(70);
      final next = controller.estimateSize(50);
      await encoder.waitForCalls(1);
      encoder.releaseNext();
      expect(await failed, isNull);
      await encoder.waitForCalls(2);
      encoder.releaseNext();
      expect(await next, 50);
      expect(encoder.maxActive, 1);
    });

    test('PNG shares one estimate across qualities', () async {
      final encoder = CountingEncoder();
      final controller = await loadedController(
        config: ChatImageEditorConfig(
          export: ExportOptions(format: ExportFormat.png, encoder: encoder),
        ),
      );
      final a = await controller.estimateSize(90);
      final b = await controller.estimateSize(20);
      expect(a, b);
      expect(encoder.calls, 1);
    });

    test('returns null when encoding fails, and retries later', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(
          export: ExportOptions(encoder: FailingEncoder()),
        ),
      );
      expect(await controller.estimateSize(50), isNull);
      controller.config = const ChatImageEditorConfig();
      expect(await controller.estimateSize(50), greaterThan(0));
    });
  });

  test('estimates follow the crop', () async {
    final controller = await loadedController(
      bytes: noisyPng(64, 64),
      config: const ChatImageEditorConfig(
        export: ExportOptions(format: ExportFormat.png),
      ),
    );
    final full = await controller.estimateSize(80);
    controller.setCrop(const Rect.fromLTRB(0, 0, 0.5, 0.5));
    final cropped = await controller.estimateSize(80);
    expect(cropped, lessThan(full!));
  });
}

/// Holds every encode until [releaseNext] is called and tracks how many run
/// at once. Each encode returns `quality` bytes.
class _GatedEncoder implements ImageEncoder {
  _GatedEncoder({this.failFirst = false});

  /// Fails the first encode instead of returning bytes.
  final bool failFirst;

  final List<Completer<void>> _gates = <Completer<void>>[];
  int _released = 0;

  /// Qualities passed to [encode], in call order.
  final List<int> qualities = <int>[];

  /// Number of [encode] calls so far.
  int get calls => qualities.length;

  /// Encodes started and not yet finished.
  int active = 0;

  /// Most encodes ever running at the same time.
  int maxActive = 0;

  /// Lets the oldest held encode finish.
  void releaseNext() => _gates[_released++].complete();

  /// Waits (up to a few seconds) until [count] encodes have started.
  Future<void> waitForCalls(int count) async {
    for (var i = 0; i < 500 && calls < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(calls, greaterThanOrEqualTo(count));
  }

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) async {
    final index = qualities.length;
    qualities.add(quality);
    final gate = Completer<void>();
    _gates.add(gate);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await gate.future;
      if (failFirst && index == 0) throw StateError('encoder failure');
      return Uint8List(quality);
    } finally {
      active--;
    }
  }
}
