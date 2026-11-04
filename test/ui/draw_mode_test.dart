import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/color_strip.dart';
import 'package:chat_image_editor/src/ui/editor_icon_button.dart';
import 'package:chat_image_editor/src/ui/editor_pill_button.dart';
import 'package:chat_image_editor/src/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

const List<Color> _palette = ChatImageEditorThemeData.defaultPalette;

/// The pen swatch that replaces the tools while drawing.
final Finder _swatch = find.descendant(
  of: find.byType(EditorTopBar),
  matching: find.byTooltip('Draw'),
);

/// The swatch's colored circle.
BoxDecoration _swatchDecoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: _swatch, matching: find.byType(AnimatedContainer)),
  );
  return container.decoration! as BoxDecoration;
}

/// The color the swatch draws its icon in.
Color? _swatchIconColor(WidgetTester tester) {
  final icon = find.descendant(of: _swatch, matching: find.byType(Icon));
  return IconTheme.of(tester.element(icon)).color;
}

/// The color slider's thumb.
final Finder _thumb = find.descendant(
  of: find.byType(ColorStrip),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

/// The color slider's semantics node.
SemanticsNode _sliderSemantics(WidgetTester tester) {
  return tester.getSemantics(
    find
        .descendant(
          of: find.byType(ColorStrip),
          matching: find.byType(Semantics),
        )
        .first,
  );
}

/// Where along the slider [t] (0 at the first color, 1 at the last) sits.
Offset _sliderPoint(WidgetTester tester, double t) {
  final rect = tester.getRect(find.byType(ColorStrip));
  const thumb = ColorStrip.thumbSize;
  final track = rect.height - thumb;
  return Offset(rect.center.dx, rect.top + thumb / 2 + t * track);
}

/// Matches a color whose channels are all within [tolerance] of [expected].
Matcher _closeToColor(Color expected, {double tolerance = 0.02}) {
  return predicate<Color>(
    (color) =>
        (color.a - expected.a).abs() <= tolerance &&
        (color.r - expected.r).abs() <= tolerance &&
        (color.g - expected.g).abs() <= tolerance &&
        (color.b - expected.b).abs() <= tolerance,
    'a color close to $expected',
  );
}

/// Opacity the chrome around [finder] is faded to.
double _chromeOpacity(WidgetTester tester, Finder finder) {
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)).last,
      )
      .opacity;
}

Future<ChatImageEditorController> _openDraw(
  WidgetTester tester, {
  ChatImageEditorConfig config = const ChatImageEditorConfig(),
  ChatImageEditorStrings strings = const ChatImageEditorStrings(),
}) async {
  final controller = await pumpReadyEditor(
    tester,
    config: config,
    strings: strings,
  );
  await tester.tap(find.byTooltip('Draw'));
  await tester.pumpAndSettle();
  expect(controller.activeTool, EditorTool.draw);
  return controller;
}

void main() {
  group('draw mode', () {
    testWidgets('draw: shows controls and records a dragged stroke', (
      tester,
    ) async {
      final controller = await _openDraw(tester);

      expect(find.byTooltip('Pen'), findsOneWidget);
      expect(find.byTooltip('Arrow'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(ColorStrip), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.dragFrom(center, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(controller.value.strokes, hasLength(1));
      expect(controller.value.strokes.single.color, controller.drawColor);
      expect(controller.canUndo, isTrue);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(controller.value.strokes, isEmpty);
    });

    testWidgets('draw: picking a shape updates the controller', (tester) async {
      final controller = await _openDraw(tester);

      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pump();
      expect(controller.shapeType, ShapeType.rectangle);
    });

    testWidgets('draw: a single offered shape is drawn without a picker', (
      tester,
    ) async {
      final controller = await _openDraw(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.arrow],
        ),
      );

      expect(find.byTooltip('Arrow'), findsNothing);
      expect(find.byTooltip('Pen'), findsNothing);
      expect(controller.shapeType, ShapeType.arrow);

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.dragFrom(center, const Offset(60, 40));
      await tester.pumpAndSettle();
      expect(controller.value.strokes.single.type, ShapeType.arrow);
    });

    testWidgets('draw: the picker highlights the first offered shape', (
      tester,
    ) async {
      final controller = await _openDraw(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.line, ShapeType.arrow],
        ),
      );

      expect(controller.shapeType, ShapeType.line);
      expect(find.byTooltip('Pen'), findsNothing);
      final line = tester.widget<EditorIconButton>(
        find.ancestor(
          of: find.byTooltip('Line'),
          matching: find.byType(EditorIconButton),
        ),
      );
      expect(line.active, isTrue);
    });

    testWidgets('draw: the active shape is an accent icon on a dark backdrop', (
      tester,
    ) async {
      await _openDraw(tester);
      final theme = scopeOf(tester, find.byTooltip('Pen')).theme;

      Color? backdrop(String tooltip) {
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration! as BoxDecoration).color;
      }

      Color? iconColor(String tooltip) {
        final icon = find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(Icon),
        );
        return IconTheme.of(tester.element(icon)).color;
      }

      expect(backdrop('Pen'), theme.toolbarBackgroundColor);
      expect(backdrop('Arrow'), theme.toolbarBackgroundColor);
      expect(iconColor('Pen'), theme.activeToolColor);
      expect(iconColor('Arrow'), theme.foregroundColor);
    });

    testWidgets('draw: the brush size is one labelled slider', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _openDraw(tester);

      // The label and the slider's value and actions share one node.
      final brush = find.semantics.byLabel('Brush size');
      final data = brush.evaluate().single.getSemanticsData();
      expect(data.value, isNotEmpty);
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);

      final before = controller.strokeWidth;
      tester.semantics.increase(brush);
      await tester.pump();
      expect(controller.strokeWidth, greaterThan(before));
      semantics.dispose();
    });

    testWidgets('draw: the chrome fades out while a stroke is drawn', (
      tester,
    ) async {
      final controller = await _openDraw(tester);
      final topBar = find.byType(EditorTopBar);
      final strip = find.byType(ColorStrip);
      final shapes = find.byTooltip('Pen');

      expect(_chromeOpacity(tester, topBar), 1);
      expect(_chromeOpacity(tester, strip), 1);
      expect(_chromeOpacity(tester, shapes), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Scaffold)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump();
      expect(controller.draftStroke, isNotNull);
      expect(_chromeOpacity(tester, topBar), 0);
      expect(_chromeOpacity(tester, strip), 0);
      expect(_chromeOpacity(tester, shapes), 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.value.strokes, hasLength(1));
      expect(_chromeOpacity(tester, topBar), 1);
      expect(_chromeOpacity(tester, strip), 1);
      expect(_chromeOpacity(tester, shapes), 1);
    });
  });

  group('draw top bar', () {
    testWidgets('morphs into a Done pill, undo and a pen swatch', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byType(EditorPillButton), findsNothing);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byTooltip('Redo'), findsNothing);
      expect(find.byTooltip('Text'), findsNothing);
      expect(find.byTooltip('Crop and rotate'), findsNothing);
      expect(find.byTooltip('Image quality'), findsNothing);
      final done = tester.widget<EditorPillButton>(
        find.byType(EditorPillButton),
      );
      expect(done.label, 'Done');
      expect(find.text('Done'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(_swatch, findsOneWidget);
      expect(_swatchDecoration(tester).color, controller.drawColor);
    });

    testWidgets('the morph animates, and the outgoing tools ignore taps', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both groups are on screen halfway through.
      expect(find.byTooltip('Crop and rotate'), findsOneWidget);
      expect(find.byType(EditorPillButton), findsOneWidget);

      await tester.tap(find.byTooltip('Crop and rotate'), warnIfMissed: false);
      await tester.pump();
      expect(controller.activeTool, EditorTool.draw);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Crop and rotate'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the outgoing tools keep their state while they fade', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      final before = tester.element(
        find.byKey(const ValueKey<String>('tools')),
      );

      controller.selectTool(EditorTool.draw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final during = tester.element(
        find.byKey(const ValueKey<String>('tools')),
      );
      expect(identical(during, before), isTrue);
    });

    testWidgets('reduced motion swaps the chrome at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byTooltip('Crop and rotate'), findsNothing);
      expect(find.byType(EditorPillButton), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(ColorStrip), findsOneWidget);

      controller.closeTool();
      await tester.pump();
      await tester.pump();
      expect(find.byType(EditorPillButton), findsNothing);
      expect(find.byType(ColorStrip), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('the Done pill ends drawing', (tester) async {
      final controller = await _openDraw(tester);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(controller.activeTool, EditorTool.none);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byType(EditorPillButton), findsNothing);
      expect(find.byType(ColorStrip), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('screen readers can tap the Done pill', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _openDraw(tester);

      final done = find.semantics.byLabel('Done');
      expect(
        done.evaluate().single.getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
      );
      tester.semantics.tap(done);
      await tester.pumpAndSettle();

      expect(controller.activeTool, EditorTool.none);
      semantics.dispose();
    });

    testWidgets('the pen swatch ends drawing', (tester) async {
      final controller = await _openDraw(tester);

      await tester.tap(_swatch);
      await tester.pumpAndSettle();

      expect(controller.activeTool, EditorTool.none);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Crop and rotate'), findsOneWidget);
      expect(find.byType(EditorPillButton), findsNothing);
    });

    testWidgets('the swatch follows drawColor with a contrasting icon', (
      tester,
    ) async {
      final controller = await _openDraw(tester);

      controller.setDrawColor(const Color(0xFFFFFFFF));
      await tester.pump();
      expect(_swatchDecoration(tester).color, const Color(0xFFFFFFFF));
      expect(_swatchIconColor(tester), const Color(0xFF000000));

      controller.setDrawColor(const Color(0xFF2196F3));
      await tester.pump();
      expect(_swatchDecoration(tester).color, const Color(0xFF2196F3));
      expect(_swatchIconColor(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('undo is hidden with showUndoRedo off', (tester) async {
      await _openDraw(
        tester,
        config: const ChatImageEditorConfig(showUndoRedo: false),
      );

      expect(find.byTooltip('Undo'), findsNothing);
      expect(_swatch, findsOneWidget);
      expect(find.byType(EditorPillButton), findsOneWidget);
    });
  });

  group('color slider', () {
    testWidgets('sits on the right below the top bar, at most 300 tall', (
      tester,
    ) async {
      await _openDraw(tester);
      final view = tester.getRect(find.byType(Scaffold));
      final strip = tester.getRect(find.byType(ColorStrip));
      final topBar = tester.getRect(find.byType(EditorTopBar));

      expect(strip.height, ColorStrip.maxHeight);
      expect(strip.width, ColorStrip.width);
      expect(strip.right, lessThanOrEqualTo(view.right));
      expect(strip.left, greaterThan(view.center.dx));
      expect(strip.top, greaterThanOrEqualTo(topBar.bottom));
    });

    testWidgets('tapping picks the color at that point', (tester) async {
      final controller = await _openDraw(tester);

      await tester.tapAt(_sliderPoint(tester, 0));
      await tester.pump();
      expect(controller.drawColor, _palette.first);

      await tester.tapAt(_sliderPoint(tester, 1));
      await tester.pump();
      expect(controller.drawColor, _palette.last);

      // Halfway between red (stop 2) and orange (stop 3).
      const t = 2.5 / 9;
      await tester.tapAt(_sliderPoint(tester, t));
      await tester.pump();
      expect(
        controller.drawColor,
        _closeToColor(Color.lerp(_palette[2], _palette[3], 0.5)!),
      );
      expect(_palette, isNot(contains(controller.drawColor)));
    });

    testWidgets('the thumb shows the current color where it was picked', (
      tester,
    ) async {
      final controller = await _openDraw(tester);

      final point = _sliderPoint(tester, 0.6);
      await tester.tapAt(point);
      await tester.pump();

      final thumb = tester.widget<DecoratedBox>(_thumb);
      expect((thumb.decoration as BoxDecoration).color, controller.drawColor);
      expect(tester.getCenter(_thumb).dy, closeTo(point.dy, 0.01));
    });

    testWidgets('dragging picks colors between the stops', (tester) async {
      final controller = await _openDraw(tester);
      final picked = <Color>[];
      controller.addListener(() {
        if (picked.isEmpty || picked.last != controller.drawColor) {
          picked.add(controller.drawColor);
        }
      });

      final gesture = await tester.startGesture(_sliderPoint(tester, 0));
      final track = _sliderPoint(tester, 1).dy - _sliderPoint(tester, 0).dy;
      for (var i = 1; i <= 20; i++) {
        await gesture.moveBy(Offset(0, track / 20));
        await tester.pump();
      }
      // Past the end stays on the last color.
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.drawColor, _palette.last);
      expect(picked.length, greaterThan(10));
      expect(
        picked.where((color) => !_palette.contains(color)),
        isNotEmpty,
        reason: 'a drag picks colors between the palette stops',
      );
      // The drag picked colors; it didn't draw.
      expect(controller.value.strokes, isEmpty);
    });

    testWidgets('dragging midway lands between two stops', (tester) async {
      final controller = await _openDraw(tester);

      final from = _sliderPoint(tester, 0);
      final to = _sliderPoint(tester, 1.5 / 9);
      final gesture = await tester.startGesture(from);
      await gesture.moveTo(Offset(from.dx, (from.dy + to.dy) / 2));
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Halfway between black (stop 1) and red (stop 2).
      expect(
        controller.drawColor,
        _closeToColor(Color.lerp(_palette[1], _palette[2], 0.5)!),
      );
    });

    testWidgets('screen readers step through the palette', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _openDraw(
        tester,
        strings: ChatImageEditorStrings(
          colorLabel: (color, index, count) => 'Swatch ${index + 1}/$count',
        ),
      );
      controller.setDrawColor(_palette[2]);
      await tester.pump();

      final slider = find.semantics.byLabel('Color');
      expect(
        _sliderSemantics(tester),
        matchesSemantics(
          label: 'Color',
          value: 'Swatch 3/10',
          increasedValue: 'Swatch 4/10',
          decreasedValue: 'Swatch 2/10',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      tester.semantics.increase(slider);
      await tester.pump();
      expect(controller.drawColor, _palette[3]);

      tester.semantics.decrease(slider);
      await tester.pump();
      tester.semantics.decrease(slider);
      await tester.pump();
      tester.semantics.decrease(slider);
      await tester.pump();
      expect(controller.drawColor, _palette.first);
      expect(
        _sliderSemantics(tester),
        matchesSemantics(
          label: 'Color',
          value: 'Swatch 1/10',
          increasedValue: 'Swatch 2/10',
          isSlider: true,
          hasIncreaseAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a color between stops reads as the nearest stop', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await _openDraw(
        tester,
        strings: ChatImageEditorStrings(
          colorLabel: (color, index, count) => 'Swatch ${index + 1}/$count',
        ),
      );

      await tester.tapAt(_sliderPoint(tester, 6.8 / 9));
      await tester.pump();
      expect(_palette, isNot(contains(controller.drawColor)));
      expect(
        _sliderSemantics(tester),
        matchesSemantics(
          label: 'Color',
          value: 'Swatch 8/10',
          increasedValue: 'Swatch 9/10',
          decreasedValue: 'Swatch 7/10',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      tester.semantics.increase(find.semantics.byLabel('Color'));
      await tester.pump();
      expect(controller.drawColor, _palette[8]);
      semantics.dispose();
    });

    testWidgets('shrinks to the space available', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _openDraw(tester);

      final strip = tester.getRect(find.byType(ColorStrip));
      expect(strip.height, lessThan(ColorStrip.maxHeight));
      expect(strip.height, greaterThanOrEqualTo(ColorStrip.thumbSize * 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('ColorStrip', () {
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);

    test('colorAt returns each palette color exactly at its stop', () {
      for (var i = 0; i < _palette.length; i++) {
        expect(
          ColorStrip.colorAt(_palette, i / (_palette.length - 1)),
          _palette[i],
        );
      }
      // `1 / 49 * 49` is a hair under 1; it still lands on the stop.
      final long = <Color>[
        for (var i = 0; i < 50; i++) Color(0xFF000000 + i * 0x050403),
      ];
      for (var i = 0; i < long.length; i++) {
        expect(ColorStrip.colorAt(long, i / (long.length - 1)), long[i]);
      }
    });

    test('colorAt blends between stops and clamps at the ends', () {
      expect(
        ColorStrip.colorAt(const <Color>[black, white], 0.5),
        _closeToColor(const Color(0xFF808080), tolerance: 0.005),
      );
      expect(
        ColorStrip.colorAt(const <Color>[red, green, blue], 0.75),
        _closeToColor(Color.lerp(green, blue, 0.5)!, tolerance: 0.005),
      );
      expect(ColorStrip.colorAt(const <Color>[red, green, blue], -1), red);
      expect(ColorStrip.colorAt(const <Color>[red, green, blue], 2), blue);
      expect(ColorStrip.colorAt(const <Color>[green], 0.3), green);
    });

    test('positionOf finds palette colors at their stops', () {
      for (var i = 0; i < _palette.length; i++) {
        expect(
          ColorStrip.positionOf(_palette, _palette[i]),
          i / (_palette.length - 1),
        );
      }
    });

    test('positionOf round-trips blended colors', () {
      const palette = <Color>[red, green, blue];
      for (final t in <double>[0.1, 0.3, 0.45, 0.6, 0.85]) {
        final color = ColorStrip.colorAt(palette, t);
        expect(ColorStrip.positionOf(palette, color), closeTo(t, 1 / 240));
      }
    });

    test('positionOf picks the nearest point for colors off the gradient', () {
      // The grey closest to pure red is a third of the way to white.
      expect(
        ColorStrip.positionOf(const <Color>[black, white], red),
        closeTo(1 / 3, 0.01),
      );
      expect(ColorStrip.positionOf(const <Color>[], red), 0);
      expect(ColorStrip.positionOf(const <Color>[green], red), 0);
    });
  });

  group('hideSystemBarsWhileDrawing', () {
    List<MethodCall> recordSystemChrome(WidgetTester tester) {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
            calls.add(call);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    const hidden = <String>[];
    final shown = <String>[
      for (final overlay in SystemUiOverlay.values) overlay.toString(),
    ];

    test('is off by default and survives copyWith', () {
      const config = ChatImageEditorConfig();
      expect(config.hideSystemBarsWhileDrawing, isFalse);

      final on = config.copyWith(hideSystemBarsWhileDrawing: true);
      expect(on.hideSystemBarsWhileDrawing, isTrue);
      expect(
        on.copyWith(showUndoRedo: false).hideSystemBarsWhileDrawing,
        isTrue,
      );
      expect(
        on
            .copyWith(hideSystemBarsWhileDrawing: false)
            .hideSystemBarsWhileDrawing,
        isFalse,
      );
    });

    testWidgets('leaves the system bars alone by default', (tester) async {
      final calls = recordSystemChrome(tester);
      final controller = await _openDraw(tester);

      controller.closeTool();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      expect(calls, isEmpty);
    });

    testWidgets('hides the bars while drawing and restores them after', (
      tester,
    ) async {
      final calls = recordSystemChrome(tester);
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(hideSystemBarsWhileDrawing: true),
      );
      expect(calls, isEmpty);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.single.arguments, hidden);

      // Changing the color or drawing doesn't touch them again.
      controller.setDrawColor(_palette[5]);
      await tester.dragFrom(
        tester.getCenter(find.byType(Scaffold)),
        const Offset(40, 40),
      );
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.last.arguments, shown);

      // Other tools keep them.
      controller.selectTool(EditorTool.crop);
      await tester.pumpAndSettle();
      controller.closeTool();
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
    });

    testWidgets('restores the bars when the editor closes mid-drawing', (
      tester,
    ) async {
      final calls = recordSystemChrome(tester);
      await _openDraw(
        tester,
        config: const ChatImageEditorConfig(hideSystemBarsWhileDrawing: true),
      );
      expect(calls.single.arguments, hidden);

      await tester.pumpWidget(const SizedBox());
      expect(calls, hasLength(2));
      expect(calls.last.arguments, shown);
    });
  });
}
