// Scripted, human-paced walkthroughs of the example chat, recorded into the
// GIF previews in doc/gifs/. This doesn't test anything: it drives the real
// app with touches while tool/record_gifs.sh records the simulator's screen.
//
// Record them all from the package root, with an iOS simulator booted:
//
//   tool/record_gifs.sh            # or: tool/record_gifs.sh draw text
//
// Or run the walkthroughs by hand from example/:
//
//   fvm flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_recording_test.dart \
//     --dart-define=SCENARIO=draw,text -d <device>
//
// Each scenario starts and ends with a short full-screen magenta flash. The
// script finds the flashes in the recording and keeps what's between them,
// so app start-up and setup never show up in a GIF.
//
// Animations run in real time (the fully live frame policy) and every pause
// is a real delay. Touches are drawn as soft circles instead of the test
// binding's debug crosshairs, and typing skips the simulator's keyboard.
// Buttons are found by their tooltips; when one can't be found, the step
// falls back to the controller's public API so a changed UI still records a
// complete walkthrough.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/app_settings.dart';
import 'package:chat_image_editor_example/src/chat/chat_screen.dart';
import 'package:chat_image_editor_example/src/chat/conversation.dart';
import 'package:chat_image_editor_example/src/chat/message_bubble.dart';
import 'package:chat_image_editor_example/src/chat/photo_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The scenarios, in the order they run. Each one becomes
/// `doc/gifs/<name>.gif`.
const List<String> scenarios = <String>[
  'chat',
  'draw',
  'text',
  'crop',
  'compress',
];

/// Comma-separated scenarios to run. Empty runs all of them.
const String _scenarioDefine = String.fromEnvironment('SCENARIO');

/// The full-screen flash that brackets each scenario in the recording.
const Color markerColor = Color(0xFFFF00FF);

/// How long the marker flash stays on screen.
const Duration markerDuration = Duration(milliseconds: 400);

/// The chat's clock. Matches the 9:41 the script puts in the status bar.
final DateTime demoTime = DateTime(2026, 1, 15, 9, 41);

const ChatImageEditorStrings _strings = ChatImageEditorStrings();

const Color _yellow = Color(0xFFFFEB3B);

/// Positions of palette colors on the color slider, from 0 (top) to 1.
/// They follow `ChatImageEditorThemeData.defaultPalette`.
const double _white = 0;
const double _red = 2 / 9;
const double _yellowStop = 4 / 9;
const double _pink = 1;

void main() {
  final binding = _DemoBinding();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final selected = _scenarioDefine
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  final unknown = selected.difference(scenarios.toSet());
  if (unknown.isNotEmpty) {
    throw ArgumentError(
      'Unknown scenario: ${unknown.join(', ')}. '
      'Pick from ${scenarios.join(', ')}.',
    );
  }

  void scenario(String name, Future<void> Function(_Demo demo) body) {
    testWidgets(
      name,
      skip: selected.isNotEmpty && !selected.contains(name),
      timeout: const Timeout(Duration(minutes: 3)),
      (tester) async {
        final demo = _Demo(tester, binding);
        await demo.launch();
        debugPrint('demo: $name');
        await body(demo);
      },
    );
  }

  scenario('chat', _chat);
  scenario('draw', _draw);
  scenario('text', _text);
  scenario('crop', _crop);
  scenario('compress', _compress);
}

// ───────────────────────── Scenarios ─────────────────────────

/// Attach the sample photo, circle a spot, add a caption, send it, open the
/// sent photo.
Future<void> _chat(_Demo demo) async {
  await demo.mark();
  await demo.pause(600);

  await demo.tapOr(find.byTooltip('Send a photo'), () {
    throw StateError('The chat composer has no "Send a photo" button.');
  });
  await demo.pause(550);
  await demo.tapOr(find.text('Sample photo'), () {
    throw StateError('The photo source sheet has no "Sample photo" option.');
  });
  final editor = await demo.waitForEditor();
  await demo.pause(400);

  await demo.tapOr(
    find.byTooltip(_strings.draw),
    () => editor.selectTool(EditorTool.draw),
  );
  await demo.pause(400);
  await demo.tapColor(
    _red,
    fallback: () => editor.setDrawColor(const Color(0xFFF44336)),
  );
  await demo.pause(200);

  // Circle the place to meet, by the lake.
  final image = demo.imageRect(editor);
  await demo.stroke(
    (t) => _loop(image, const Offset(0.68, 0.71), 0.15, 0.13, t),
    milliseconds: 700,
  );
  await demo.pause(300);
  await demo.tapOr(find.byTooltip(_strings.done), editor.closeTool);
  await demo.pause(350);

  // A caption, when the caption field is where it's expected.
  final caption = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == _strings.captionHint,
  );
  if (await demo.tap(caption)) {
    await demo.waitFor(
      () => demo.focusedField() != null,
      reason: 'the caption field to take focus',
    );
    await demo.pause(200);
    await demo.type('Here, by the lake', perCharacter: 45);
    await demo.pause(350);
  }

  await demo.tapOr(find.byTooltip(_strings.send), () {
    throw StateError('The editor has no send button.');
  });
  await demo.waitFor(
    () => find.byType(ChatImageEditor).evaluate().isEmpty,
    reason: 'the editor to close after sending',
  );
  final photo = find.byWidgetPredicate(
    (widget) => widget is MessageBubble && widget.message.image != null,
  );
  await demo.waitFor(
    () => photo.evaluate().isNotEmpty,
    reason: 'the photo to appear in the chat',
  );
  await demo.pause(900);

  await demo.tapAt(
    demo.tester.getCenter(
      find.descendant(of: photo.first, matching: find.byType(Image)),
    ),
  );
  await demo.waitForRoute(find.byType(PhotoViewerScreen));
  await demo.pause(1200);
  await demo.mark();
}

/// The draw tool: colors, freehand, arrow, circle, undo and redo.
Future<void> _draw(_Demo demo) async {
  final editor = await demo.openEditor();
  await demo.mark();
  await demo.pause(500);

  await demo.tapOr(
    find.byTooltip(_strings.draw),
    () => editor.selectTool(EditorTool.draw),
  );
  await demo.pause(550);

  // Slide down the color slider, from white to yellow.
  await demo.slideColor(
    from: _white,
    to: _yellowStop,
    milliseconds: 600,
    fallback: () => editor.setDrawColor(_yellow),
  );
  await demo.pause(200);

  final image = demo.imageRect(editor);
  await demo.stroke(
    (t) =>
        _at(image, 0.08 + 0.42 * t, 0.86 + 0.025 * math.sin(t * 4 * math.pi)),
    milliseconds: 700,
  );
  await demo.pause(250);

  await demo.tapOr(
    find.byTooltip(_strings.arrow),
    () => editor.setShapeType(ShapeType.arrow),
  );
  await demo.pause(200);
  await demo.stroke(
    (t) => Offset.lerp(_at(image, 0.3, 0.64), _at(image, 0.55, 0.4), t)!,
    milliseconds: 450,
  );
  await demo.pause(200);

  await demo.tapColor(
    _pink,
    fallback: () => editor.setDrawColor(const Color(0xFFE91E63)),
  );
  await demo.pause(200);
  await demo.tapOr(
    find.byTooltip(_strings.circle),
    () => editor.setShapeType(ShapeType.circle),
  );
  await demo.pause(200);
  await demo.stroke(
    (t) => Offset.lerp(_at(image, 0.6, 0.14), _at(image, 0.9, 0.44), t)!,
    milliseconds: 500,
  );
  await demo.pause(400);

  await demo.tapOr(find.byTooltip(_strings.undo), editor.undo);
  await demo.pause(550);
  // Redo lives in the regular top bar; use it in draw mode if it's there.
  final redoWhileDrawing = await demo.tap(find.byTooltip(_strings.redo));
  if (redoWhileDrawing) await demo.pause(450);
  await demo.tapOr(find.byTooltip(_strings.done), editor.closeTool);
  await demo.pause(450);
  if (!redoWhileDrawing) {
    await demo.tapOr(find.byTooltip(_strings.redo), editor.redo);
  }
  await demo.pause(900);
  await demo.mark();
}

/// The text tool: type, color, background, then move along an alignment
/// guide and pinch to scale and rotate.
Future<void> _text(_Demo demo) async {
  final editor = await demo.openEditor();
  await demo.mark();
  await demo.pause(400);

  await demo.tapOr(
    find.byTooltip(_strings.text),
    () => editor.selectTool(EditorTool.text),
  );
  await demo.waitFor(
    () => editor.editingTextId != null && demo.focusedField() != null,
    reason: 'text entry to open',
  );
  await demo.pause(350);
  await demo.type('Meet here 📍', perCharacter: 60);
  await demo.pause(300);

  await demo.slideColor(
    from: _white,
    to: _yellowStop,
    milliseconds: 550,
    fallback: () => editor.setTextColor(_yellow),
  );
  await demo.pause(250);
  await demo.tapOr(
    find.byTooltip(_strings.textBackground),
    editor.cycleTextBackground,
  );
  await demo.pause(500);
  await demo.tapOr(find.byTooltip(_strings.done), () {
    editor
      ..finishTextEditing()
      ..closeTool();
  });
  await demo.pause(500);

  // Drag it away, back to the vertical center line, where the alignment
  // guide shows, then up along it.
  final image = demo.imageRect(editor);
  final start = demo.textCenter(editor, image);
  final out = start + Offset(image.width * 0.2, image.height * 0.22);
  final center = start + const Offset(3, -12);
  final end = start + Offset(2, -image.height * 0.3);
  await demo.stroke(
    (t) => t < 0.4
        ? Offset.lerp(start, out, _ease(t, 0, 0.4))!
        : t < 0.7
        ? Offset.lerp(out, center, _ease(t, 0.4, 0.7))!
        : Offset.lerp(center, end, _ease(t, 0.7, 1))!,
    milliseconds: 1300,
    curve: Curves.linear,
  );
  await demo.pause(400);

  // Pinch out and twist.
  final focal = demo.textCenter(editor, image);
  await demo.pinch(
    focal,
    fromSpan: 60,
    toSpan: 112,
    fromAngle: 0,
    toAngle: -0.38,
    milliseconds: 850,
  );
  await demo.pause(800);
  await demo.mark();
}

/// The crop tool: rotate, flip, square, drag a corner, confirm.
Future<void> _crop(_Demo demo) async {
  final editor = await demo.openEditor();
  await demo.mark();
  await demo.pause(600);

  await demo.tapOr(
    find.byTooltip(_strings.crop),
    () => editor.selectTool(EditorTool.crop),
  );
  await demo.pause(700);
  await demo.tapOr(find.byTooltip(_strings.rotateLeft), editor.rotateLeft);
  await demo.pause(700);
  await demo.tapOr(
    find.byTooltip(_strings.flipHorizontal),
    editor.flipHorizontal,
  );
  await demo.pause(650);
  await demo.tapOr(find.text('1:1'), () => editor.setCropAspectRatio(1));
  await demo.pause(700);

  // Pull the bottom-right corner in, then nudge the frame up.
  final frame = demo.cropFrame(editor);
  final corner = frame.bottomRight - const Offset(4, 4);
  final pull = Offset(-frame.width * 0.24, -frame.height * 0.24);
  await demo.stroke((t) => corner + pull * t, milliseconds: 650);
  await demo.pause(350);
  final moved = demo.cropFrame(editor);
  await demo.stroke(
    (t) => moved.center + Offset(moved.width * 0.04, -moved.height * 0.16) * t,
    milliseconds: 500,
  );
  await demo.pause(450);

  await demo.tapOr(find.byTooltip(_strings.confirm), () {
    editor
      ..confirmCrop()
      ..closeTool();
  });
  await demo.pause(1300);
  await demo.mark();
}

/// The quality sheet: lower the quality, watch the estimate, apply, send.
Future<void> _compress(_Demo demo) async {
  final editor = await demo.openEditor();
  await demo.mark();
  await demo.pause(500);

  await demo.tapOr(
    find.byTooltip(_strings.compress),
    () => editor.selectTool(EditorTool.compress),
  );
  await demo.waitForEstimate();
  await demo.pause(500);

  await demo.slideQuality(from: editor.quality, to: 40, milliseconds: 800);
  await demo.waitForEstimate();
  await demo.pause(700);

  await demo.tapOr(find.text(_strings.apply), () {
    editor
      ..setQuality(40)
      ..commitQuality()
      ..closeTool();
  });
  await demo.pause(500);
  await demo.tapOr(find.byTooltip(_strings.send), () {
    throw StateError('The editor has no send button.');
  });
  await demo.waitFor(
    () => find.byType(ChatImageEditor).evaluate().isEmpty,
    reason: 'the editor to close after sending',
  );
  await demo.pause(1300);
  await demo.mark();
}

// ───────────────────────── Geometry ─────────────────────────

/// Eased progress through the part of [t] between [from] and [to].
double _ease(double t, double from, double to) =>
    Curves.easeInOut.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

/// The point at ([x], [y]) normalized over [rect].
Offset _at(Rect rect, double x, double y) =>
    Offset(rect.left + rect.width * x, rect.top + rect.height * y);

/// A hand-drawn loop around [center] (normalized over [image]), a little
/// more than one turn so it closes.
Offset _loop(Rect image, Offset center, double rx, double ry, double t) {
  final angle = -math.pi * 0.75 + t * math.pi * 2.15;
  final wobble = 1 + 0.06 * math.sin(t * math.pi * 3);
  return _at(
    image,
    center.dx + rx * wobble * math.cos(angle),
    center.dy + ry * wobble * math.sin(angle),
  );
}

// ───────────────────────── Driver ─────────────────────────

/// Drives one scenario: launching the app, touches, typing and waits.
class _Demo {
  _Demo(this.tester, this.binding);

  final WidgetTester tester;
  final _DemoBinding binding;

  /// Starts the example chat and warms it up off the record.
  Future<void> launch() async {
    binding.touches.clear();
    final settings = AppSettings(themeMode: ThemeMode.light);
    final conversation = Conversation.demo(clock: () => demoTime);
    addTearDown(settings.dispose);
    addTearDown(conversation.dispose);
    await tester.pumpWidget(
      _DemoApp(
        settings: settings,
        conversation: conversation,
        touches: binding.touches,
        marker: binding.marker,
      ),
    );
    await waitFor(
      () => find.byType(ChatScreen).evaluate().isNotEmpty,
      reason: 'the chat to show',
    );
    await pause(300);
    await _warmUp();
  }

  /// Opens the editor once, runs a size estimate and closes it again.
  ///
  /// Simulators only run debug builds, where Dart code is compiled the
  /// first time it runs. Without this, the first export of a run takes
  /// several times longer than the next one (and far longer than in a
  /// release build), the first photo bubble stays blank for a second while
  /// the image decoder starts, and the chat generates the sample photo on
  /// camera.
  Future<void> _warmUp() async {
    final controller = await openEditor();
    // Exporting runs the render and encode code; decoding the JPEG it made
    // wakes the platform's image decoder, which the chat's bubbles use.
    final result = await controller.export();
    if (result != null) {
      final codec = await ui.instantiateImageCodec(
        result.bytes,
        targetWidth: 64,
      );
      (await codec.getNextFrame()).image.dispose();
      codec.dispose();
    }
    // The editor ignores touches while it exports; let it rebuild first.
    await pause(300);
    await tapOr(find.byTooltip(_strings.close), () {
      Navigator.of(tester.element(find.byType(ChatImageEditor))).pop();
    });
    await waitFor(
      () => find.byType(ChatImageEditor).evaluate().isEmpty,
      reason: 'the editor to close',
    );
    await pause(400);
  }

  /// Flashes the marker the recording script cuts at.
  Future<void> mark() async {
    binding.marker.value = true;
    await pause(markerDuration.inMilliseconds);
    binding.marker.value = false;
    await _nextFrame();
  }

  /// Opens the editor on the sample photo through the chat, off the record.
  Future<ChatImageEditorController> openEditor() async {
    await tapOr(find.byTooltip('Send a photo'), () {
      throw StateError('The chat composer has no "Send a photo" button.');
    });
    await pause(500);
    await tapOr(find.text('Sample photo'), () {
      throw StateError('The photo source sheet has no "Sample photo" option.');
    });
    final editor = await waitForEditor();
    await pause(300);
    return editor;
  }

  /// The open editor's controller.
  ChatImageEditorController get editor => tester
      .widget<ChatImageEditorScope>(find.byType(ChatImageEditorScope))
      .controller;

  /// Waits until the editor's route is in place and its photo has loaded.
  Future<ChatImageEditorController> waitForEditor() async {
    await waitForRoute(find.byType(ChatImageEditor));
    await waitFor(
      () => find.byType(ChatImageEditorScope).evaluate().isNotEmpty,
      reason: 'the editor to open',
    );
    final controller = editor;
    await waitFor(
      () => controller.loadStatus == ImageLoadStatus.ready,
      reason: 'the photo to load',
    );
    return controller;
  }

  /// Waits until [finder] shows up and its route finished animating in.
  Future<void> waitForRoute(Finder finder) async {
    await waitFor(
      () => finder.evaluate().isNotEmpty,
      reason: 'a route with $finder',
    );
    await waitFor(() {
      final elements = finder.evaluate();
      if (elements.isEmpty) return false;
      final animation = ModalRoute.of(elements.first)?.animation;
      return animation == null || animation.isCompleted;
    }, reason: 'the route with $finder to finish its transition');
  }

  /// Waits until the quality sheet's size estimate is done.
  Future<void> waitForEstimate() async {
    final sheet = find
        .ancestor(
          of: find.text(_strings.estimatedSizeLabel),
          matching: find.byType(Material),
        )
        .first;
    await waitFor(
      () => find.text(_strings.estimatedSizeLabel).evaluate().isNotEmpty,
      reason: 'the quality sheet to open',
    );
    await waitFor(
      () => find
          .descendant(
            of: sheet,
            matching: find.byWidgetPredicate((w) => w is ProgressIndicator),
          )
          .evaluate()
          .isEmpty,
      reason: 'the size estimate',
      timeout: const Duration(seconds: 40),
    );
  }

  /// Where the editor shows the photo outside crop mode.
  Rect imageRect(ChatImageEditorController controller) {
    final editorFinder = find.byType(ChatImageEditor);
    final safe = MediaQuery.viewPaddingOf(tester.element(editorFinder));
    final output = ImageGeometry.outputSize(
      controller.originalSize,
      controller.value,
    );
    return ImageGeometry.fitRect(
      output,
      safe.deflateRect(tester.getRect(editorFinder)),
    );
  }

  /// The crop frame on screen, in crop mode.
  Rect cropFrame(ChatImageEditorController controller) {
    final editorFinder = find.byType(ChatImageEditor);
    final safe = MediaQuery.viewPaddingOf(tester.element(editorFinder));
    // The space the editor keeps around the image in crop mode.
    final padding = safe + const EdgeInsets.fromLTRB(24, 32, 24, 136);
    final output = ImageGeometry.outputSize(
      controller.originalSize,
      controller.value.copyWith(clearCrop: true),
    );
    final image = ImageGeometry.fitRect(
      output,
      padding.deflateRect(tester.getRect(editorFinder)),
    );
    final crop = controller.value.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    return Rect.fromLTRB(
      image.left + crop.left * image.width,
      image.top + crop.top * image.height,
      image.left + crop.right * image.width,
      image.top + crop.bottom * image.height,
    );
  }

  /// The center of the newest text layer on screen.
  Offset textCenter(ChatImageEditorController controller, Rect image) {
    final layer = controller.value.texts.last;
    final view = ImageGeometry.originalToView(
      layer.position,
      controller.originalSize,
      controller.value,
    );
    return _at(image, view.dx, view.dy);
  }

  // ─────────────── Touches ───────────────

  /// Taps at [position] like a finger: down, a short hold, up.
  Future<void> tapAt(Offset position) async {
    final gesture = await tester.startGesture(position);
    await pause(90);
    await gesture.up();
  }

  /// Taps the center of the first hit-testable match of [finder]. Returns
  /// `false`, without tapping, when there's none.
  Future<bool> tap(Finder finder) async {
    final target = finder.hitTestable();
    if (target.evaluate().isEmpty) return false;
    await tapAt(tester.getCenter(target.first));
    return true;
  }

  /// Taps [finder], or runs [fallback] when it isn't on screen.
  Future<void> tapOr(Finder finder, VoidCallback fallback) async {
    if (await tap(finder)) return;
    debugPrint('demo: nothing to tap for $finder, using the controller');
    fallback();
  }

  /// Drags one finger along [path] (from `path(0)` to `path(1)`), one move
  /// per frame.
  Future<void> stroke(
    Offset Function(double t) path, {
    required int milliseconds,
    Curve curve = Curves.easeInOut,
  }) async {
    final steps = math.max(2, milliseconds ~/ 16);
    final gesture = await tester.startGesture(path(0));
    await pause(40);
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(path(curve.transform(i / steps)));
      await pause(16);
    }
    await pause(60);
    await gesture.up();
  }

  /// A two-finger pinch around [focal]: the fingers spread from [fromSpan]
  /// to [toSpan] apart while turning from [fromAngle] to [toAngle].
  Future<void> pinch(
    Offset focal, {
    required double fromSpan,
    required double toSpan,
    required double fromAngle,
    required double toAngle,
    required int milliseconds,
  }) async {
    Offset half(double t) {
      final span = fromSpan + (toSpan - fromSpan) * t;
      final angle = fromAngle + (toAngle - fromAngle) * t;
      return Offset(math.cos(angle), math.sin(angle)) * (span / 2);
    }

    // The first finger lands on the text, so the gesture grabs it.
    final first = await tester.startGesture(focal - half(0) * 0.25);
    await pause(30);
    final second = await tester.startGesture(focal + half(0));
    await pause(60);
    final steps = math.max(2, milliseconds ~/ 16);
    for (var i = 1; i <= steps; i++) {
      final t = Curves.easeInOut.transform(i / steps);
      // The first finger starts near the focal point and settles into a
      // symmetric pinch over the first fifth of the gesture.
      final settle = math.min(1.0, i / (steps * 0.2));
      final firstHalf = half(t) * (0.25 + 0.75 * settle);
      await first.moveTo(focal - firstHalf);
      await second.moveTo(focal + half(t));
      await pause(16);
    }
    await pause(60);
    await first.up();
    await pause(20);
    await second.up();
  }

  // ─────────────── Color slider ───────────────

  Finder get _colorStrip => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'ColorStrip',
  );

  /// The point at [t] along the visible color slider, or `null` when there
  /// is none.
  Offset? _colorAt(double t) {
    final strip = _colorStrip.hitTestable();
    if (strip.evaluate().isEmpty) return null;
    final rect = tester.getRect(strip.first);
    // The gradient runs between the centers of the thumb's end positions.
    const thumb = 26.0;
    return Offset(
      rect.center.dx,
      rect.top + thumb / 2 + (rect.height - thumb) * t,
    );
  }

  /// Drags along the color slider from [from] to [to].
  Future<void> slideColor({
    required double from,
    required double to,
    required int milliseconds,
    required VoidCallback fallback,
  }) async {
    final start = _colorAt(from);
    final end = _colorAt(to);
    if (start == null || end == null) {
      debugPrint('demo: no color slider, using the controller');
      fallback();
      return;
    }
    await stroke(
      (t) => Offset.lerp(start, end, t)!,
      milliseconds: milliseconds,
    );
  }

  /// Taps the color slider at [t].
  Future<void> tapColor(double t, {required VoidCallback fallback}) async {
    final point = _colorAt(t);
    if (point == null) {
      debugPrint('demo: no color slider, using the controller');
      fallback();
      return;
    }
    await tapAt(point);
  }

  // ─────────────── Quality slider ───────────────

  /// Drags the quality sheet's slider from quality [from] to [to].
  Future<void> slideQuality({
    required int from,
    required int to,
    required int milliseconds,
  }) async {
    final slider = find.byType(Slider).hitTestable();
    if (slider.evaluate().isEmpty) {
      debugPrint('demo: no quality slider, using the controller');
      editor.setQuality(to);
      return;
    }
    final widget = tester.widget<Slider>(slider.first);
    final rect = tester.getRect(slider.first);
    // Material sliders inset their track by the thumb overlay's radius.
    const inset = 24.0;
    double x(int quality) {
      final t = (quality - widget.min) / (widget.max - widget.min);
      return rect.left + inset + (rect.width - inset * 2) * t;
    }

    final y = rect.center.dy;
    await stroke(
      (t) => Offset(x(from) + (x(to) - x(from)) * t, y),
      milliseconds: milliseconds,
    );
  }

  // ─────────────── Typing ───────────────

  /// The text field with keyboard focus, if any.
  EditableTextState? focusedField() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return null;
    if (context is StatefulElement && context.state is EditableTextState) {
      return context.state as EditableTextState;
    }
    return context.findAncestorStateOfType<EditableTextState>();
  }

  /// Types [text] into the focused field, one character at a time, as the
  /// keyboard would.
  Future<void> type(String text, {int perCharacter = 85}) async {
    final field = focusedField();
    if (field == null) throw StateError('No text field has focus.');
    var typed = '';
    for (final character in text.characters) {
      typed += character;
      field.userUpdateTextEditingValue(
        TextEditingValue(
          text: typed,
          selection: TextSelection.collapsed(offset: typed.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await pause(perCharacter);
    }
  }

  // ─────────────── Time ───────────────

  /// Waits [milliseconds] of real time while the app keeps animating.
  Future<void> pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  /// Polls [condition] until it holds.
  Future<void> waitFor(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final clock = Stopwatch()..start();
    while (!condition()) {
      if (clock.elapsed > timeout) {
        throw TimeoutException('Timed out waiting for $reason.', timeout);
      }
      await pause(30);
    }
  }

  Future<void> _nextFrame() {
    final done = Completer<void>();
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => done.complete())
      ..scheduleFrame();
    return done.future;
  }
}

// ───────────────────────── App ─────────────────────────

/// The example app (as in `lib/src/app.dart`) with a fixed clock, plus the
/// touch indicators and the recording marker on top.
class _DemoApp extends StatelessWidget {
  const _DemoApp({
    required this.settings,
    required this.conversation,
    required this.touches,
    required this.marker,
  });

  final AppSettings settings;
  final Conversation conversation;
  final _Touches touches;
  final ValueListenable<bool> marker;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => MaterialApp(
              title: 'Chat image editor',
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: settings.themeFor(Brightness.light),
              darkTheme: settings.themeFor(Brightness.dark),
              home: ChatScreen(settings: settings, conversation: conversation),
            ),
          ),
          IgnorePointer(child: _TouchLayer(touches: touches)),
          IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: marker,
              builder: (context, on, _) => on
                  ? const ColoredBox(color: markerColor)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The integration test binding, with touches dispatched like a real
/// finger's. The live test binding draws a debug crosshair at every touch a
/// test sends; these go around it, and [touches] records them for
/// [_TouchLayer] instead.
class _DemoBinding extends IntegrationTestWidgetsFlutterBinding {
  final _Touches touches = _Touches();

  /// Fills the screen with [markerColor] while `true`.
  final ValueNotifier<bool> marker = ValueNotifier<bool>(false);

  /// Typing goes to a stand-in keyboard, so the simulator's own keyboard
  /// (its first-launch stall and locale-dependent suggestions) stays out
  /// of the recording.
  @override
  bool get registerTestTextInput => true;

  @override
  void handlePointerEvent(PointerEvent event) {
    if (pointerEventSource != TestBindingEventSource.test) {
      super.handlePointerEvent(event);
      return;
    }
    touches.handle(event);
    final propagate = shouldPropagateDevicePointerEvents;
    shouldPropagateDevicePointerEvents = true;
    try {
      withPointerEventSource(
        TestBindingEventSource.device,
        () => super.handlePointerEvent(event),
      );
    } finally {
      shouldPropagateDevicePointerEvents = propagate;
    }
  }
}

class _Touch {
  _Touch(this.position);

  Offset position;
  Duration? releasedAt;
}

/// Fingers on the screen, and the ones that just lifted.
class _Touches extends ChangeNotifier {
  final Stopwatch clock = Stopwatch()..start();
  final Map<int, _Touch> _touches = <int, _Touch>{};

  /// How long a touch takes to fade after the finger lifts.
  static const Duration fade = Duration(milliseconds: 240);

  Iterable<_Touch> get all => _touches.values;

  bool get isEmpty => _touches.isEmpty;

  void handle(PointerEvent event) {
    switch (event) {
      case PointerDownEvent():
        _touches[event.pointer] = _Touch(event.position);
      case PointerMoveEvent():
        _touches[event.pointer]?.position = event.position;
      case PointerUpEvent() || PointerCancelEvent():
        _touches[event.pointer]?.releasedAt = clock.elapsed;
      default:
        return;
    }
    notifyListeners();
  }

  /// Forgets every touch, including any a failed gesture left down.
  void clear() {
    if (_touches.isEmpty) return;
    _touches.clear();
    notifyListeners();
  }

  /// Forgets touches that have faded out.
  void prune() {
    final now = clock.elapsed;
    _touches.removeWhere((_, touch) {
      final released = touch.releasedAt;
      return released != null && now - released >= fade;
    });
  }
}

/// Draws a soft circle under each finger, like the "show touches" option of
/// screen recorders.
class _TouchLayer extends StatefulWidget {
  const _TouchLayer({required this.touches});

  final _Touches touches;

  @override
  State<_TouchLayer> createState() => _TouchLayerState();
}

class _TouchLayerState extends State<_TouchLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    widget.touches.addListener(_changed);
  }

  @override
  void dispose() {
    widget.touches.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _tick(Duration _) {
    widget.touches.prune();
    if (widget.touches.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TouchPainter(
        touches: widget.touches.all.toList(),
        now: widget.touches.clock.elapsed,
      ),
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter({required this.touches, required this.now});

  final List<_Touch> touches;
  final Duration now;

  static const double radius = 21;

  @override
  void paint(Canvas canvas, Size size) {
    for (final touch in touches) {
      final released = touch.releasedAt;
      final fade = released == null
          ? 0.0
          : ((now - released).inMicroseconds / _Touches.fade.inMicroseconds)
                .clamp(0.0, 1.0);
      final opacity = 1 - fade;
      if (opacity <= 0) continue;
      final r = radius * (1 + 0.3 * fade);
      canvas
        ..drawCircle(
          touch.position,
          r,
          Paint()
            ..color = const Color(0x8C9E9E9E).withValues(alpha: 0.55 * opacity),
        )
        ..drawCircle(
          touch.position,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85 * opacity),
        )
        ..drawCircle(
          touch.position,
          r + 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withValues(alpha: 0.25 * opacity),
        );
    }
  }

  @override
  bool shouldRepaint(_TouchPainter oldDelegate) => true;
}
