import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/editor_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('draw mode', () {
    testWidgets('draw: shows controls and records a dragged stroke', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.draw);
      expect(find.byTooltip('Pen'), findsOneWidget);
      expect(find.byTooltip('Arrow'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.dragFrom(center, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(controller.value.strokes, hasLength(1));
      expect(controller.canUndo, isTrue);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(controller.value.strokes, isEmpty);
    });

    testWidgets('draw: picking a shape and a color updates the controller', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pump();
      expect(controller.shapeType, ShapeType.rectangle);

      final before = controller.drawColor;
      const palette = ChatImageEditorThemeData.defaultPalette;
      final target = palette.firstWhere((color) => color != before);
      // Tap the swatch for [target] in the strip.
      final swatch = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == target,
      );
      await tester.tap(swatch);
      await tester.pump();
      expect(controller.drawColor, target);
    });

    testWidgets('draw: a single offered shape is drawn without a picker', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.arrow],
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
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
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.line, ShapeType.arrow],
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
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

    testWidgets('draw: screen readers can pick each swatch', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpReadyEditor(
        tester,
        strings: ChatImageEditorStrings(
          colorLabel: (color, index, count) => 'Swatch ${index + 1}/$count',
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();

      const palette = ChatImageEditorThemeData.defaultPalette;
      for (var i = 0; i < palette.length; i++) {
        expect(
          tester.getSemantics(find.bySemanticsLabel('Swatch ${i + 1}/10')),
          matchesSemantics(
            label: 'Swatch ${i + 1}/10',
            isButton: true,
            hasTapAction: true,
            hasSelectedState: true,
            isSelected: palette[i] == controller.drawColor,
          ),
        );
      }

      final target = palette.indexWhere((c) => c != controller.drawColor);
      tester.semantics.tap(find.semantics.byLabel('Swatch ${target + 1}/10'));
      await tester.pump();
      expect(controller.drawColor, palette[target]);
      semantics.dispose();
    });
  });
}
