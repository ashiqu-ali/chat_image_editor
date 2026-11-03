import 'dart:async';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../core/test_utils.dart';
import 'controller_helpers.dart';

/// An encoder that waits for [release] before encoding.
class GatedEncoder implements ImageEncoder {
  final Completer<void> release = Completer<void>();

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) async {
    await release.future;
    return Uint8List(10);
  }
}

void main() {
  test('returns null before an image is loaded', () async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    expect(await controller.export(), isNull);
    expect(controller.isExporting, isFalse);
  });

  test('exports the edits at full resolution with a trimmed caption', () async {
    final controller = await loadedController(
      config: const ChatImageEditorConfig(previewMaxLongEdge: 20),
    );
    controller
      ..startStroke(const Offset(0.1, 0.5))
      ..updateStroke(const Offset(0.9, 0.5))
      ..endStroke();
    final result = await controller.export(caption: '  Look at this  ');
    expect(result, isNotNull);
    expect(result!.width, 80);
    expect(result.height, 60);
    expect(result.format, ExportFormat.jpeg);
    expect(result.mimeType, 'image/jpeg');
    expect(result.caption, 'Look at this');
    expect(result.edits, controller.value);
    expect(result.exceedsMaxBytes, isFalse);
    final decoded = img.decodeJpg(result.bytes)!;
    expect(decoded.width, 80);
    expect(decoded.height, 60);
  });

  test('the result carries export stats', () async {
    final encoder = CountingEncoder();
    final controller = await loadedController(
      config: ChatImageEditorConfig(
        export: ExportOptions(quality: 80, encoder: encoder),
      ),
    );
    controller
      ..startStroke(const Offset(0.1, 0.5))
      ..updateStroke(const Offset(0.9, 0.5))
      ..endStroke();
    final result = await controller.export();
    final stats = result!.stats;
    expect(stats, isNotNull);
    expect(stats!.sourceByteLength, controller.sourceBytes!.length);
    expect(stats.outputByteLength, result.bytes.length);
    expect(stats.outputWidth, result.width);
    expect(stats.outputHeight, result.height);
    expect(stats.encodeAttempts, encoder.calls);
    expect(stats.finalQuality, 80);
    expect(stats.decodeTime, greaterThanOrEqualTo(Duration.zero));
    expect(stats.renderTime, greaterThanOrEqualTo(Duration.zero));
    expect(stats.encodeTime, greaterThanOrEqualTo(Duration.zero));
    expect(
      stats.totalTime,
      greaterThanOrEqualTo(
        stats.decodeTime + stats.renderTime + stats.encodeTime,
      ),
    );
  });

  test('stats count the attempts of the maxBytes ladder', () async {
    final encoder = FakeEncoder();
    final controller = await loadedController(
      config: ChatImageEditorConfig(
        export: ExportOptions(maxBytes: 7000, encoder: encoder),
      ),
    );
    final result = await controller.export();
    // 100 bytes per quality point: 90 and 80 are too big, 70 fits.
    expect(encoder.qualities, <int>[90, 80, 70]);
    expect(result!.stats!.encodeAttempts, 3);
    expect(result.stats!.finalQuality, 70);
    expect(result.stats!.outputByteLength, result.bytes.length);
  });

  test('rotation swaps the exported width and height', () async {
    final controller = await loadedController();
    controller.rotateLeft();
    final result = await controller.export();
    expect(result!.width, 60);
    expect(result.height, 80);
  });

  test('text layers export with textLayerStyle', () async {
    final controller = await loadedController(
      config: const ChatImageEditorConfig(
        defaultFontSize: 0.25,
        export: ExportOptions(format: ExportFormat.png),
      ),
    );
    expect(controller.textLayerStyle.fontWeight, FontWeight.w600);
    controller
      ..addText()
      ..updateEditingText('Hi')
      ..finishTextEditing();
    final plain = await controller.export();

    const spaced = TextStyle(
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 12,
    );
    expect(
      notificationsDuring(controller, () => controller.textLayerStyle = spaced),
      1,
    );
    expect(
      notificationsDuring(controller, () => controller.textLayerStyle = spaced),
      0,
    );
    final styled = await controller.export();
    expect(styled!.bytes, isNot(equals(plain!.bytes)));
  });

  test('crop and maxLongEdge shape the output', () async {
    final controller = await loadedController(
      config: const ChatImageEditorConfig(
        export: ExportOptions(maxLongEdge: 20),
      ),
    );
    controller.setCrop(const Rect.fromLTRB(0, 0, 0.5, 1));
    final result = await controller.export();
    // Crop: 40×60, long edge capped to 20.
    expect(result!.width, 13);
    expect(result.height, 20);
  });

  test('exports PNG when configured', () async {
    final controller = await loadedController(
      config: const ChatImageEditorConfig(
        export: ExportOptions(format: ExportFormat.png),
      ),
    );
    final result = await controller.export();
    expect(result!.format, ExportFormat.png);
    final decoded = img.decodePng(result.bytes)!;
    expect(decodedPixel(decoded, 5, 5), rgbaCloseTo(red));
  });

  test('starts from the picked quality and flags maxBytes overruns', () async {
    final encoder = FakeEncoder();
    final controller = await loadedController(
      config: ChatImageEditorConfig(
        export: ExportOptions(maxBytes: 1000, minQuality: 40, encoder: encoder),
      ),
    );
    controller
      ..selectTool(EditorTool.compress)
      ..setQuality(65)
      ..closeTool();
    final result = await controller.export();
    expect(encoder.qualities, <int>[65, 55, 45, 40]);
    expect(result!.exceedsMaxBytes, isTrue);
    expect(result.bytes.length, 4000);
  });

  test('isExporting brackets the export; a second call returns null', () async {
    final encoder = GatedEncoder();
    final controller = await loadedController(
      config: ChatImageEditorConfig(export: ExportOptions(encoder: encoder)),
    );
    final states = <bool>[];
    controller.addListener(() => states.add(controller.isExporting));

    final first = controller.export();
    expect(controller.isExporting, isTrue);
    expect(await controller.export(), isNull);
    encoder.release.complete();
    expect(await first, isNotNull);
    expect(controller.isExporting, isFalse);
    expect(states, <bool>[true, false]);
  });

  test('returns null and reports the error when encoding fails', () async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final controller = await loadedController(
      config: const ChatImageEditorConfig(
        export: ExportOptions(encoder: FailingEncoder()),
      ),
    );
    expect(await controller.export(), isNull);
    expect(controller.isExporting, isFalse);
    expect(errors, hasLength(1));
    expect(errors.single.exception, isA<StateError>());
  });
}
