import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('discard confirmation', () {
    testWidgets('closes right away without changes', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(tester, onCancel: () => cancelled++);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(cancelled, 1);
    });

    testWidgets('asks before discarding a caption', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(tester, onCancel: () => cancelled++);

      await tester.enterText(find.byType(TextFormField), 'A caption');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your edits to this image will be lost.'), findsOne);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(cancelled, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    });

    testWidgets('asks before discarding edits', (tester) async {
      var cancelled = 0;
      final controller = await pumpReadyEditor(
        tester,
        onCancel: () => cancelled++,
      );

      controller
        ..selectTool(EditorTool.crop)
        ..rotateRight()
        ..confirmCrop();
      await tester.pumpAndSettle();
      expect(controller.hasChanges, isTrue);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    });

    testWidgets('uses themed colors and custom strings', (tester) async {
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(
          sheetBackgroundColor: Color(0xFF222244),
        ),
        strings: const ChatImageEditorStrings(
          discardTitle: 'Tout effacer ?',
          discardMessage: 'Vos modifications seront perdues.',
          discardConfirm: 'Effacer',
          keepEditing: 'Continuer',
        ),
        captionField: const CaptionFieldConfig(),
      );

      await tester.enterText(find.byType(TextFormField), 'Bonjour');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Tout effacer ?'), findsOneWidget);
      expect(find.text('Vos modifications seront perdues.'), findsOneWidget);
      expect(find.text('Effacer'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFF222244));
    });

    testWidgets('builders.confirmDiscard replaces the dialog', (tester) async {
      var asked = 0;
      var cancelled = 0;
      ChatImageEditorScope? scope;
      var answer = false;
      await pumpReadyEditor(
        tester,
        builders: ChatImageEditorBuilders(
          confirmDiscard: (context) async {
            asked++;
            scope = ChatImageEditorScope.maybeOf(context);
            return answer;
          },
        ),
        onCancel: () => cancelled++,
      );

      await tester.enterText(find.byType(TextFormField), 'Unsaved');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(scope, isNotNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(cancelled, 0);

      answer = true;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(asked, 2);
      expect(cancelled, 1);
    });

    testWidgets('is skipped when config.confirmDiscard is off', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(confirmDiscard: false),
        onCancel: () => cancelled++,
      );

      await tester.enterText(find.byType(TextFormField), 'Unsaved');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(cancelled, 1);
    });

    testWidgets('system back closes an open tool first', (tester) async {
      var cancelled = 0;
      final controller = await pumpReadyEditor(
        tester,
        onCancel: () => cancelled++,
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.draw);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(cancelled, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    });
  });
}
