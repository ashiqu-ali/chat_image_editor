import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/crop_overlay.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('crop mode', () {
    testWidgets('crop: rotate and confirm', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.crop);
      expect(find.byTooltip('Rotate left'), findsOneWidget);
      expect(find.byTooltip('Flip horizontally'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.byTooltip('Rotate right'));
      await tester.pump();
      expect(controller.value.quarterTurns, 1);

      await tester.tap(find.text('1:1'));
      await tester.pump();
      expect(controller.cropAspectRatio, 1);

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.quarterTurns, 1);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('crop: cancel restores the image', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pump();
      await tester.tap(find.byTooltip('Flip vertically'));
      await tester.pump();
      expect(controller.value.flipY || controller.value.flipX, isTrue);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.hasChanges, isFalse);
    });

    testWidgets('crop: dragging a corner changes the crop', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pumpAndSettle();
      expect(controller.value.crop, isNull);

      // The frame starts on the whole image; grab its bottom-right corner.
      final overlay = find.byType(CropOverlay);
      final image = EditorLayout.imageRect(
        tester.getSize(overlay),
        EditorLayout.canvasPadding(tester.element(overlay), EditorTool.crop),
        EditorLayout.paintedOutputSize(controller),
      ).shift(tester.getTopLeft(overlay));
      await tester.dragFrom(
        image.bottomRight - const Offset(2, 2),
        const Offset(-60, -40),
      );
      await tester.pump();

      final crop = controller.value.crop;
      expect(crop, isNotNull);
      expect(crop!.right, lessThan(1));
      expect(crop.bottom, lessThan(1));
    });
  });
}
