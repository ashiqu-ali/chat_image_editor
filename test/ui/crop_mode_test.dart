import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/crop_controls.dart';
import 'package:chat_image_editor/src/ui/crop_overlay.dart';
import 'package:chat_image_editor/src/ui/editor_icon_button.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

/// The bottom row's tooltips, in order.
const List<String> rowTooltips = <String>[
  'Cancel',
  'Rotate left',
  'Rotate right',
  'Flip horizontally',
  'Flip vertically',
  'Reset',
  'Done',
];

/// Opens the crop tool and lets the other chrome finish animating out.
Future<void> openCrop(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Crop and rotate'));
  await tester.pumpAndSettle();
}

/// The whole rotated image as the crop overlay shows it, in global
/// coordinates. The crop frame covers it until the crop changes.
Rect cropImageRect(WidgetTester tester, ChatImageEditorController controller) {
  final overlay = find.byType(CropOverlay);
  return EditorLayout.imageRect(
    tester.getSize(overlay),
    EditorLayout.canvasPadding(tester.element(overlay), EditorTool.crop),
    EditorLayout.paintedOutputSize(controller),
  ).shift(tester.getTopLeft(overlay));
}

/// Everything tappable in the crop controls, in tree order.
Finder cropControlTargets() {
  return find.descendant(
    of: find.byType(CropControls),
    matching: find.byType(InkResponse),
  );
}

/// The area the crop controls' buttons and chips cover.
Rect cropControlsRect(WidgetTester tester) {
  return cropControlTargets()
      .evaluate()
      .map((element) => tester.getRect(find.byWidget(element.widget)))
      .reduce((a, b) => a.expandToInclude(b));
}

/// Whether the aspect-ratio chip labelled [label] reports itself selected.
bool chipSelected(WidgetTester tester, String label) {
  final semantics = tester.widgetList<Semantics>(
    find.ancestor(of: find.text(label), matching: find.byType(Semantics)),
  );
  return semantics
      .firstWhere((s) => s.properties.selected != null)
      .properties
      .selected!;
}

/// Shows the editor on a [size] screen with [padding] as its safe area.
void setScreen(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}

void main() {
  group('crop mode', () {
    testWidgets('crop: rotate and confirm', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await openCrop(tester);
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

      await openCrop(tester);
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

      await openCrop(tester);
      expect(controller.value.crop, isNull);

      // The frame starts on the whole image; grab its bottom-right corner.
      final image = cropImageRect(tester, controller);
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

    testWidgets('crop: hides the top bar and keeps one bottom row', (
      tester,
    ) async {
      await pumpReadyEditor(tester);
      expect(find.byTooltip('Close'), findsOneWidget);

      await openCrop(tester);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byTooltip('Crop and rotate'), findsNothing);
      expect(find.byTooltip('Undo'), findsNothing);

      final buttons = tester
          .widgetList<EditorIconButton>(
            find.descendant(
              of: find.byType(CropControls),
              matching: find.byType(EditorIconButton),
            ),
          )
          .toList();
      expect(buttons.map((b) => b.tooltip), rowTooltips);
      expect(buttons.every((b) => b.backdrop), isTrue);
      // Only confirm is drawn in the accent color.
      expect(buttons.map((b) => b.active), <bool>[
        false,
        false,
        false,
        false,
        false,
        false,
        true,
      ]);

      // One row, left to right, below the aspect-ratio chips.
      final centers = <Offset>[
        for (final tooltip in rowTooltips)
          tester.getCenter(find.byTooltip(tooltip)),
      ];
      for (var i = 1; i < centers.length; i++) {
        expect(centers[i].dx, greaterThan(centers[i - 1].dx));
        expect(centers[i].dy, moreOrLessEquals(centers[0].dy));
      }
      expect(tester.getCenter(find.text('Free')).dy, lessThan(centers[0].dy));
    });

    testWidgets('crop: aspect-ratio chips lock the frame', (tester) async {
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);

      final labels = <String>['Free', '1:1', '4:3', '3:4', '16:9', '9:16'];
      final xs = <double>[
        for (final label in labels) tester.getCenter(find.text(label)).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      expect(controller.cropAspectRatio, isNull);
      expect(chipSelected(tester, 'Free'), isTrue);

      await tester.tap(find.text('16:9'));
      await tester.pump();
      expect(controller.cropAspectRatio, closeTo(16 / 9, 1e-9));
      expect(chipSelected(tester, '16:9'), isTrue);
      expect(chipSelected(tester, 'Free'), isFalse);
      // The frame on screen has the chosen shape.
      final image = cropImageRect(tester, controller);
      final crop = controller.value.crop!;
      expect(
        crop.width * image.width / (crop.height * image.height),
        closeTo(16 / 9, 0.01),
      );

      await tester.tap(find.text('Free'));
      await tester.pump();
      expect(controller.cropAspectRatio, isNull);
      expect(chipSelected(tester, 'Free'), isTrue);
    });

    testWidgets('crop: chips follow config.cropAspectRatios', (tester) async {
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(cropAspectRatios: <double>[1.5]),
      );
      await openCrop(tester);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('3:2'), findsOneWidget);
      expect(find.text('1:1'), findsNothing);

      await tester.tap(find.text('3:2'));
      await tester.pump();
      expect(controller.cropAspectRatio, 1.5);
    });

    testWidgets('crop: no chips without aspect ratios', (tester) async {
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(cropAspectRatios: <double>[]),
      );
      await openCrop(tester);
      expect(find.text('Free'), findsNothing);
      for (final tooltip in rowTooltips) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }
    });

    testWidgets('crop: reset clears the crop, rotation, flips and lock', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);

      await tester.tap(find.byTooltip('Rotate right'));
      await tester.tap(find.byTooltip('Flip horizontally'));
      await tester.tap(find.text('1:1'));
      await tester.pump();
      expect(controller.value.quarterTurns, 1);
      expect(controller.value.crop, isNotNull);
      expect(controller.cropAspectRatio, 1);

      await tester.tap(find.byTooltip('Reset'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.crop);
      expect(controller.value.quarterTurns, 0);
      expect(controller.value.flipX, isFalse);
      expect(controller.value.flipY, isFalse);
      expect(controller.value.crop, isNull);
      expect(controller.cropAspectRatio, isNull);

      // Confirming a reset session leaves nothing to undo.
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.hasChanges, isFalse);
      expect(controller.canUndo, isFalse);
    });

    testWidgets('crop: confirm records one history entry', (tester) async {
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);

      await tester.tap(find.byTooltip('Rotate right'));
      await tester.tap(find.byTooltip('Rotate right'));
      await tester.tap(find.byTooltip('Flip vertically'));
      await tester.tap(find.text('16:9'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      final confirmed = controller.value;
      expect(confirmed.quarterTurns, 2);
      expect(confirmed.crop, isNotNull);

      controller.undo();
      expect(controller.value, ImageEditValue.empty);
      expect(controller.canUndo, isFalse);
      controller.redo();
      expect(controller.value, confirmed);
    });

    testWidgets('crop: cancel restores the state from when crop opened', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);
      await tester.tap(find.byTooltip('Rotate right'));
      await tester.tap(find.text('1:1'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      final confirmed = controller.value;

      await openCrop(tester);
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.tap(find.byTooltip('Flip vertically'));
      await tester.tap(find.text('Free'));
      await tester.pump();
      final image = cropImageRect(tester, controller);
      await tester.dragFrom(
        image.topLeft + const Offset(2, 2),
        Offset(image.width / 4, image.height / 4),
      );
      await tester.pump();
      expect(controller.value, isNot(confirmed));

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value, confirmed);
      expect(controller.cropAspectRatio, 1);

      // The cancelled session added no history entry.
      controller.undo();
      expect(controller.value, ImageEditValue.empty);
      expect(controller.canUndo, isFalse);
    });

    testWidgets('crop: the frame handles stay clear of the controls', (
      tester,
    ) async {
      expect(
        EditorLayout.cropHandleClearance,
        greaterThanOrEqualTo(CropOverlay.cornerSlop),
      );
      final screens = <(Size, FakeViewPadding)>[
        (const Size(800, 600), FakeViewPadding.zero),
        // A landscape phone, where the image's height is the limit.
        (
          const Size(844, 390),
          const FakeViewPadding(left: 47, right: 47, bottom: 21),
        ),
        (const Size(390, 844), const FakeViewPadding(top: 47, bottom: 34)),
        (const Size(320, 568), FakeViewPadding.zero),
      ];
      for (final (size, padding) in screens) {
        setScreen(tester, size, padding: padding);
        final controller = await pumpReadyEditor(tester);
        await openCrop(tester);

        final image = cropImageRect(tester, controller);
        final controls = cropControlsRect(tester);
        final reason = '$size, bottom padding ${padding.bottom}';
        // The controls are as tall as the inset assumes, or shorter where
        // the button row scales down to fit a narrow screen.
        final height = size.height - padding.bottom - controls.top;
        expect(height, lessThanOrEqualTo(CropControls.height), reason: reason);
        if (size.width >= 390) {
          expect(height, moreOrLessEquals(CropControls.height), reason: reason);
        }
        expect(
          controls.bottom,
          lessThanOrEqualTo(size.height - padding.bottom),
        );
        // No handle's touch area reaches the controls or the safe area.
        expect(
          controls.top - image.bottom,
          greaterThanOrEqualTo(CropOverlay.cornerSlop),
          reason: reason,
        );
        expect(
          image.top - CropOverlay.cornerSlop,
          greaterThanOrEqualTo(padding.top),
          reason: reason,
        );
        expect(
          image.left,
          greaterThanOrEqualTo(padding.left + EditorLayout.cropSideInset),
          reason: reason,
        );
        expect(
          image.right,
          lessThanOrEqualTo(
            size.width - padding.right - EditorLayout.cropSideInset,
          ),
          reason: reason,
        );
        controller.closeTool();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('crop: edge handles are grabbed next to the controls', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);

      // Just below the frame's bottom edge, between it and the chips.
      final image = cropImageRect(tester, controller);
      expect(
        cropControlsRect(tester).top,
        greaterThan(image.bottom + CropOverlay.edgeSlop),
      );
      await tester.dragFrom(
        image.bottomCenter + const Offset(0, CropOverlay.edgeSlop - 2),
        const Offset(0, -60),
      );
      await tester.pump();
      expect(controller.value.crop!.bottom, lessThan(1));
      expect(controller.cropAspectRatio, isNull);

      // And just above the top edge.
      await tester.dragFrom(
        image.topCenter - const Offset(0, CropOverlay.edgeSlop - 2),
        const Offset(0, 60),
      );
      await tester.pump();
      expect(controller.value.crop!.top, greaterThan(0));
    });

    testWidgets('crop: everything fits a 320×568 screen', (tester) async {
      setScreen(tester, const Size(320, 568));
      final controller = await pumpReadyEditor(tester);
      await openCrop(tester);
      expect(tester.takeException(), isNull);

      const screen = Rect.fromLTWH(0, 0, 320, 568);
      Rect? previous;
      for (final tooltip in rowTooltips) {
        final rect = tester.getRect(find.byTooltip(tooltip));
        expect(screen.intersect(rect), rect, reason: tooltip);
        if (previous != null) {
          expect(rect.left, greaterThanOrEqualTo(previous.right - 0.01));
        }
        previous = rect;
      }
      expect(screen.contains(tester.getCenter(find.text('Free'))), isTrue);

      // The scaled-down row still works.
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pump();
      expect(controller.value.quarterTurns, 3);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(tester.takeException(), isNull);
    });
  });

  group('system back', () {
    testWidgets('cancels the crop and keeps the editor open', (tester) async {
      var cancelled = 0;
      final controller = await pumpReadyEditor(
        tester,
        onCancel: () => cancelled++,
      );
      await openCrop(tester);
      await tester.tap(find.byTooltip('Rotate right'));
      await tester.tap(find.byTooltip('Flip horizontally'));
      await tester.tap(find.text('1:1'));
      await tester.pump();
      expect(controller.value, isNot(ImageEditValue.empty));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cancelled, 0);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value, ImageEditValue.empty);
      expect(controller.cropAspectRatio, isNull);
      expect(controller.canUndo, isFalse);
      expect(find.byType(CropControls), findsNothing);
      expect(find.byTooltip('Crop and rotate'), findsOneWidget);

      // With the crop closed, back closes the editor.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    });

    testWidgets('cancels the crop before popping the editor route', (
      tester,
    ) async {
      final bytes = testPng();
      final controller = ChatImageEditorController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.load(bytes));

      Future<ChatImageEditorResult?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  result = ChatImageEditor.open(
                    context,
                    bytes,
                    controller: controller,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await openCrop(tester);
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ChatImageEditor), findsOneWidget);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.quarterTurns, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ChatImageEditor), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('finishes text entry', (tester) async {
      var cancelled = 0;
      final controller = await pumpReadyEditor(
        tester,
        onCancel: () => cancelled++,
      );
      await tester.tap(find.byTooltip('Text'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cancelled, 0);
      expect(controller.editingTextId, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.texts.single.text, 'Hello');
    });

    testWidgets('closes the compress sheet', (tester) async {
      var cancelled = 0;
      final controller = await pumpReadyEditor(
        tester,
        onCancel: () => cancelled++,
      );
      await tester.tap(find.byTooltip('Image quality'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.compress);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cancelled, 0);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.canUndo, isFalse);
    });
  });
}
