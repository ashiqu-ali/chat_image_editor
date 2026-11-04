import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

/// Runs a test once as Android and once as iOS.
const androidAndIos = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// Types a caption and taps close, so the editor has unsaved work to ask
/// about.
Future<void> closeWithCaption(
  WidgetTester tester, [
  String caption = 'Unsaved',
]) async {
  await tester.enterText(find.byType(TextFormField), caption);
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
}

/// Expects that neither default dialog is showing.
void expectNoDialog() {
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.byType(CupertinoAlertDialog), findsNothing);
}

/// The Cupertino action labelled [label].
CupertinoDialogAction cupertinoAction(WidgetTester tester, String label) {
  return tester.widget<CupertinoDialogAction>(
    find.widgetWithText(CupertinoDialogAction, label),
  );
}

/// Foreground color of the Material dialog button labelled [label].
Color? materialButtonColor(WidgetTester tester, String label) {
  final button = tester.widget<TextButton>(
    find.widgetWithText(TextButton, label),
  );
  return button.style?.foregroundColor?.resolve(<WidgetState>{});
}

void main() {
  group('discard confirmation', () {
    testWidgets('closes right away without changes', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(tester, onCancel: () => cancelled++);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expectNoDialog();
      expect(cancelled, 1);
    }, variant: androidAndIos);

    testWidgets('asks before discarding a caption', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(tester, onCancel: () => cancelled++);

      await closeWithCaption(tester, 'A caption');

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your edits to this image will be lost.'), findsOne);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('A caption'), findsOneWidget);
      expect(cancelled, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    }, variant: androidAndIos);

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

    testWidgets('is skipped when config.confirmDiscard is off', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(confirmDiscard: false),
        onCancel: () => cancelled++,
      );

      await closeWithCaption(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expectNoDialog();
      expect(cancelled, 1);
    }, variant: androidAndIos);

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

      await closeWithCaption(tester);

      expect(asked, 1);
      expect(scope, isNotNull);
      expectNoDialog();
      expect(cancelled, 0);

      answer = true;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(asked, 2);
      expect(cancelled, 1);
    }, variant: androidAndIos);

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

  group('Material dialog', () {
    testWidgets('is shown on Android with an error-colored discard', (
      tester,
    ) async {
      await pumpReadyEditor(tester);

      await closeWithCaption(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      final dialogContext = tester.element(find.byType(AlertDialog));
      expect(
        materialButtonColor(tester, 'Discard'),
        Theme.of(dialogContext).colorScheme.error,
      );
      final scope = scopeOf(tester, find.byTooltip('Close'));
      expect(
        materialButtonColor(tester, 'Keep editing'),
        scope.theme.primaryColor,
      );
      // The safe choice comes first, the destructive one last.
      expect(
        tester.getCenter(find.text('Keep editing')).dx,
        lessThan(tester.getCenter(find.text('Discard')).dx),
      );
    });

    testWidgets('a barrier tap or back keeps editing', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(tester, onCancel: () => cancelled++);

      await closeWithCaption(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expectNoDialog();
      expect(find.text('Unsaved'), findsOneWidget);
      expect(cancelled, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectNoDialog();
      expect(find.text('Unsaved'), findsOneWidget);
      expect(cancelled, 0);
    });

    testWidgets('uses themed colors and custom strings', (tester) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(
          colorScheme: const ColorScheme.dark(error: Color(0xFFFF5252)),
        ),
        theme: const ChatImageEditorThemeData(
          primaryColor: Color(0xFF00897B),
          sheetBackgroundColor: Color(0xFF222244),
        ),
        strings: const ChatImageEditorStrings(
          discardTitle: 'Tout effacer ?',
          discardMessage: 'Vos modifications seront perdues.',
          discardConfirm: 'Effacer',
          keepEditing: 'Continuer',
        ),
      );

      await closeWithCaption(tester, 'Bonjour');

      expect(find.text('Tout effacer ?'), findsOneWidget);
      expect(find.text('Vos modifications seront perdues.'), findsOneWidget);
      expect(find.text('Effacer'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFF222244));
      expect(materialButtonColor(tester, 'Effacer'), const Color(0xFFFF5252));
      expect(materialButtonColor(tester, 'Continuer'), const Color(0xFF00897B));
    });

    testWidgets('follows the app theme platform over the device', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.android),
      );

      await closeWithCaption(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Cupertino dialog', () {
    testWidgets(
      'is shown on iOS and macOS with destructive and default actions',
      (tester) async {
        await pumpReadyEditor(tester);

        await closeWithCaption(tester);

        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Discard changes?'), findsOneWidget);
        expect(find.text('Your edits to this image will be lost.'), findsOne);

        final keep = cupertinoAction(tester, 'Keep editing');
        expect(keep.isDefaultAction, isTrue);
        expect(keep.isDestructiveAction, isFalse);
        final discard = cupertinoAction(tester, 'Discard');
        expect(discard.isDestructiveAction, isTrue);
        expect(discard.isDefaultAction, isFalse);
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }),
    );

    testWidgets('follows the app theme platform over the device', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.iOS),
      );

      await closeWithCaption(tester);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('closes only through its actions', (tester) async {
      var cancelled = 0;
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.iOS),
        onCancel: () => cancelled++,
      );

      await closeWithCaption(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expectNoDialog();
      expect(find.text('Unsaved'), findsOneWidget);
      expect(cancelled, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectNoDialog();
      expect(cancelled, 1);
    });

    testWidgets('is dark over the default dark sheet', (tester) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.iOS),
      );

      await closeWithCaption(tester);

      final context = tester.element(find.text('Keep editing'));
      expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    });

    testWidgets('uses themed colors and custom strings', (tester) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.iOS),
        theme: const ChatImageEditorThemeData(
          primaryColor: Color(0xFF00897B),
          sheetBackgroundColor: Color(0xFFF5F5F5),
        ),
        strings: const ChatImageEditorStrings(
          discardTitle: 'Tout effacer ?',
          discardMessage: 'Vos modifications seront perdues.',
          discardConfirm: 'Effacer',
          keepEditing: 'Continuer',
        ),
      );

      await closeWithCaption(tester, 'Bonjour');

      expect(find.text('Tout effacer ?'), findsOneWidget);
      expect(find.text('Vos modifications seront perdues.'), findsOneWidget);
      expect(cupertinoAction(tester, 'Effacer').isDestructiveAction, isTrue);
      expect(cupertinoAction(tester, 'Continuer').isDefaultAction, isTrue);

      // A light sheet gives a light alert tinted with the editor accent.
      final context = tester.element(find.text('Continuer'));
      expect(CupertinoTheme.brightnessOf(context), Brightness.light);
      expect(CupertinoTheme.of(context).primaryColor, const Color(0xFF00897B));
    });
  });
}
