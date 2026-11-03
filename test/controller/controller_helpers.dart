import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';

/// Size of the default test source image.
const Size sourceSize = Size(80, 60);

/// The default test source image: an 80×60 quadrant PNG.
final Uint8List sourcePng = quadrantPng(80, 60);

/// A controller that has finished loading [bytes] (default [sourcePng]).
/// Disposed automatically after the test.
Future<ChatImageEditorController> loadedController({
  ChatImageEditorConfig config = const ChatImageEditorConfig(),
  ImageEditValue initialValue = ImageEditValue.empty,
  Uint8List? bytes,
}) async {
  final controller = ChatImageEditorController(
    config: config,
    initialValue: initialValue,
  );
  addTearDown(controller.dispose);
  await controller.load(bytes ?? sourcePng);
  expect(controller.loadStatus, ImageLoadStatus.ready);
  return controller;
}

/// Runs [action] and returns how many times [notifier] notified.
int notificationsDuring(ChangeNotifier notifier, void Function() action) {
  var count = 0;
  void listener() => count++;
  notifier.addListener(listener);
  try {
    action();
  } finally {
    notifier.removeListener(listener);
  }
  return count;
}

/// Maps a layer-local direction (mirror, then clockwise rotation, as the
/// renderer paints it) through the controller's current transform and
/// returns the resulting on-screen direction in output pixels.
Offset screenDirection(
  TextLayer layer,
  Offset localDirection,
  Size original,
  ImageEditValue value,
) {
  var d = layer.mirrored
      ? Offset(-localDirection.dx, localDirection.dy)
      : localDirection;
  final cos = math.cos(layer.rotation);
  final sin = math.sin(layer.rotation);
  d = Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);

  const step = 0.01;
  final center = layer.position;
  final tip = Offset(
    center.dx + d.dx * step / original.width,
    center.dy + d.dy * step / original.height,
  );
  final output = ImageGeometry.outputSize(original, value);
  final a = ImageGeometry.originalToView(center, original, value);
  final b = ImageGeometry.originalToView(tip, original, value);
  return Offset(
    (b.dx - a.dx) * output.width / step,
    (b.dy - a.dy) * output.height / step,
  );
}
