// Frame timings of the editor's interactive gestures, on a real device.
//
// Profile mode, with one JSON summary per gesture in build/:
//
//   fvm flutter drive --driver=test_driver/perf_driver.dart \
//     --target=integration_test/editor_performance_test.dart --profile -d <device>
//
// Or as a plain test run (no files written):
//
//   fvm flutter test integration_test -d <device>
//
// See doc/PERFORMANCE.md in the package for what the summaries mean.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/sample_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Time between two pointer moves: one frame at 60 Hz.
const Duration frameInterval = Duration(milliseconds: 16);

/// Space the editor keeps around the image in crop mode, inside the safe
/// area, so the crop frame's corners can be found from the public API.
const EdgeInsets cropModeInsets = EdgeInsets.fromLTRB(24, 32, 24, 136);

/// A text layer to drag, in normalized original space.
const TextLayer dragText = TextLayer(
  id: 'perf-text',
  text: 'Drag me',
  position: Offset(0.5, 0.35),
  fontSize: 0.1,
  color: Color(0xFFFFFFFF),
  background: TextBackgroundStyle.solid,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List sampleImage;

  setUpAll(() async {
    sampleImage = await generateSampleImage();
  });

  /// Records frame timings of [action] under [reportKey] with
  /// `watchPerformance`. Frames are scheduled by the framework, as in the
  /// app, instead of one per pump.
  Future<void> watch(String reportKey, Future<void> Function() action) async {
    final previous = binding.framePolicy;
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
    try {
      await binding.watchPerformance(action, reportKey: reportKey);
    } finally {
      binding.framePolicy = previous;
    }
  }

  testWidgets('drawing long freehand strokes', (tester) async {
    final controller = await openEditor(tester, sampleImage);
    controller.selectTool(EditorTool.draw);
    await tester.pumpAndSettle();

    final image = imageRect(tester, controller);
    await watch('draw_strokes', () async {
      for (var stroke = 0; stroke < 4; stroke++) {
        await drawStroke(tester, image, stroke);
      }
    });

    expect(controller.value.strokes, hasLength(4));
  });

  testWidgets('dragging a text layer', (tester) async {
    final controller = await openEditor(
      tester,
      sampleImage,
      initialValue: const ImageEditValue(texts: <TextLayer>[dragText]),
    );

    final image = imageRect(tester, controller);
    final start = toScreen(image, controller, dragText.position);
    await watch('drag_text', () async {
      final gesture = await tester.startGesture(start);
      // A loop around the start, then off to the right.
      const steps = 90;
      final radius = image.shortestSide * 0.15;
      for (var i = 1; i <= steps; i++) {
        final angle = i / steps * 2 * math.pi;
        final drift = image.width * 0.15 * i / steps;
        await gesture.moveTo(
          start +
              Offset(
                math.sin(angle) * radius + drift,
                (1 - math.cos(angle)) * -radius / 2,
              ),
        );
        await tester.pump(frameInterval);
      }
      await gesture.up();
      await settleFrames(tester);
    });

    final moved = controller.textById(dragText.id);
    expect(moved, isNotNull, reason: 'the layer must not be dragged away');
    expect(moved!.position, isNot(dragText.position));
  });

  testWidgets('dragging a crop handle', (tester) async {
    final controller = await openEditor(tester, sampleImage);
    controller.selectTool(EditorTool.crop);
    await tester.pumpAndSettle();

    final image = imageRect(tester, controller, cropMode: true);
    final corner = image.bottomRight - const Offset(2, 2);
    await watch('crop_handle', () async {
      final gesture = await tester.startGesture(corner);
      // Pull the corner in towards the center, then partly back out.
      const steps = 60;
      for (var i = 1; i <= steps; i++) {
        final t = i <= 40 ? i / 40 : 1 - (i - 40) / 40;
        await gesture.moveTo(
          corner - Offset(image.width * 0.4 * t, image.height * 0.4 * t),
        );
        await tester.pump(frameInterval);
      }
      await gesture.up();
      await settleFrames(tester);
    });

    expect(controller.value.crop, isNotNull);
    controller.confirmCrop();
    await tester.pumpAndSettle();
  });

  testWidgets('pinch-zooming the preview', (tester) async {
    final controller = await openEditor(tester, sampleImage);

    final center = imageRect(tester, controller).center;
    final spread = imageRect(tester, controller).width * 0.35;
    await watch('pinch_zoom', () async {
      final first = await tester.startGesture(center - const Offset(20, 0));
      final second = await tester.startGesture(center + const Offset(20, 0));
      // Spread the fingers to zoom in, then bring them back to zoom out.
      const steps = 80;
      for (var i = 1; i <= steps; i++) {
        final t = i <= 40 ? i / 40 : 1 - (i - 40) / 40;
        final half = 20 + (spread - 20) * t;
        await first.moveTo(center - Offset(half, half * 0.2));
        await second.moveTo(center + Offset(half, half * 0.2));
        await tester.pump(frameInterval);
      }
      await first.up();
      await second.up();
      await settleFrames(tester);
    });

    // Zoom is view state, not an edit.
    expect(controller.hasChanges, isFalse);
  });
}

/// Shows the editor for [image] in done mode (no caption field, so the
/// keyboard never covers the image) and waits until it has loaded.
Future<ChatImageEditorController> openEditor(
  WidgetTester tester,
  Uint8List image, {
  ImageEditValue initialValue = ImageEditValue.empty,
}) async {
  final controller = ChatImageEditorController(
    config: const ChatImageEditorConfig(
      mode: ChatImageEditorMode.done,
      enableHaptics: false,
    ),
    initialValue: initialValue,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatImageEditor(
        image: image,
        controller: controller,
        onComplete: (_) {},
        onCancel: () {},
      ),
    ),
  );
  for (var i = 0; i < 200; i++) {
    if (controller.loadStatus != ImageLoadStatus.loading &&
        controller.loadStatus != ImageLoadStatus.idle) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(controller.loadStatus, ImageLoadStatus.ready);
  await tester.pumpAndSettle();
  return controller;
}

/// Where the editor shows the image, in global coordinates: the output
/// fitted inside the editor's safe area (plus [cropModeInsets] in crop
/// mode, where the whole uncropped image shows).
Rect imageRect(
  WidgetTester tester,
  ChatImageEditorController controller, {
  bool cropMode = false,
}) {
  final editor = find.byType(ChatImageEditor);
  final safe = MediaQuery.viewPaddingOf(tester.element(editor));
  var padding = EdgeInsets.fromLTRB(
    safe.left,
    safe.top,
    safe.right,
    safe.bottom,
  );
  var value = controller.value;
  if (cropMode) {
    padding += cropModeInsets;
    value = value.copyWith(clearCrop: true);
  }
  final output = ImageGeometry.outputSize(controller.originalSize, value);
  return ImageGeometry.fitRect(
    output,
    padding.deflateRect(tester.getRect(editor)),
  );
}

/// The screen position of [original], a point in normalized original space.
Offset toScreen(
  Rect image,
  ChatImageEditorController controller,
  Offset original,
) {
  final view = ImageGeometry.originalToView(
    original,
    controller.originalSize,
    controller.value,
  );
  return image.topLeft + Offset(view.dx * image.width, view.dy * image.height);
}

/// Draws a long wavy stroke across the middle of [image], one move per
/// frame. Strokes stay in the central area, clear of the tool controls.
Future<void> drawStroke(WidgetTester tester, Rect image, int index) async {
  const steps = 60;
  final y = 0.35 + index * 0.1;
  Offset at(int step) {
    final t = step / steps;
    return Offset(
      image.left + image.width * (0.2 + 0.6 * t),
      image.top + image.height * (y + 0.06 * math.sin(t * math.pi * 4)),
    );
  }

  final gesture = await tester.startGesture(at(0));
  for (var step = 1; step <= steps; step++) {
    await gesture.moveTo(at(step));
    await tester.pump(frameInterval);
  }
  await gesture.up();
  await settleFrames(tester);
}

/// Lets the frames triggered by the last gesture finish.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(frameInterval);
  }
}
