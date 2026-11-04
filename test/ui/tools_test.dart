import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/caption_bar.dart';
import 'package:chat_image_editor/src/ui/color_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('tools', () {
    testWidgets('every tool fits a small phone screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await pumpReadyEditor(tester);
      final screen = Offset.zero & const Size(320, 568);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The color slider stays on screen and clear of the draw toolbar.
      final strip = tester.getRect(find.byType(ColorStrip));
      final slider = tester.getRect(find.byType(Slider));
      final pen = tester.getRect(find.byTooltip('Pen'));
      expect(screen.contains(strip.topLeft), isTrue);
      expect(screen.contains(strip.bottomRight), isTrue);
      expect(strip.bottom, lessThanOrEqualTo(pen.top));
      expect(screen.contains(slider.bottomRight), isTrue);
      expect(tester.getRect(find.byTooltip('Arrow')).right, lessThan(320));
      controller.closeTool();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      controller.closeTool();
      await tester.pumpAndSettle();

      // The quality sheet's size estimate needs real async work, so its
      // spinner never settles here: pump through the transition instead.
      await tester.tap(find.byTooltip('Image quality'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      controller.closeTool();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Text'));
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('crop controls take taps while the caption slides out', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.crop);

      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pump();
      expect(controller.value.quarterTurns, 3);

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pump();
      expect(controller.value.quarterTurns, 2);
    });

    for (final tool in <String>['Text', 'Crop and rotate', 'Draw']) {
      testWidgets('opening "$tool" slides the same caption bar out', (
        tester,
      ) async {
        await pumpReadyEditor(tester);
        final caption = find.byType(EditorBottomBar);
        final before = tester.element(caption);

        await tester.tap(find.byTooltip(tool));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Still on screen, sliding out, and never rebuilt from scratch.
        expect(caption, findsOneWidget);
        expect(identical(tester.element(caption), before), isTrue);

        await tester.pump(const Duration(milliseconds: 400));
        expect(caption, findsNothing);
        final hidden = tester.element(
          find.byType(EditorBottomBar, skipOffstage: false),
        );
        expect(identical(hidden, before), isTrue);
      });
    }
  });
}
