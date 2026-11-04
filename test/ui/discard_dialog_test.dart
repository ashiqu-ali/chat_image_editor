import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Color the text [label] is actually painted with.
Color textColor(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  return paragraph.text.style!.color!;
}

/// WCAG contrast ratio between [a] and [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The dark scheme the dialogs derive their accents from on a dark sheet.
ColorScheme darkSchemeFor(Color primary) {
  return ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark);
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

      // The default sheet is dark, so the accents come from a dark scheme
      // seeded with the editor's primary color.
      final scope = scopeOf(tester, find.byTooltip('Close'));
      final darkScheme = darkSchemeFor(scope.theme.primaryColor);
      expect(materialButtonColor(tester, 'Discard'), darkScheme.error);
      expect(materialButtonColor(tester, 'Keep editing'), darkScheme.primary);
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

    testWidgets('keeps both actions readable on the default sheet', (
      tester,
    ) async {
      await pumpReadyEditor(tester, appTheme: ThemeData());

      await closeWithCaption(tester);

      final appTheme = Theme.of(tester.element(find.byType(AlertDialog)));
      expect(appTheme.useMaterial3, isTrue);
      expect(appTheme.brightness, Brightness.light);
      final sheet = scopeOf(
        tester,
        find.byTooltip('Close'),
      ).theme.sheetBackgroundColor;
      // The light app's own error color would be too dim here.
      expect(contrastRatio(appTheme.colorScheme.error, sheet), lessThan(4.5));

      expect(
        contrastRatio(textColor(tester, 'Keep editing'), sheet),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(textColor(tester, 'Discard'), sheet),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('derives the accents from the editor primary on a dark '
        'sheet', (tester) async {
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(
          primaryColor: Color(0xFF00897B),
          sheetBackgroundColor: Color(0xFF222244),
        ),
      );

      await closeWithCaption(tester);

      final darkScheme = darkSchemeFor(const Color(0xFF00897B));
      expect(textColor(tester, 'Keep editing'), darkScheme.primary);
      expect(textColor(tester, 'Discard'), darkScheme.error);
      for (final label in <String>['Keep editing', 'Discard']) {
        expect(
          contrastRatio(textColor(tester, label), const Color(0xFF222244)),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets('keeps the app colors on a light sheet, with custom strings', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(
          colorScheme: const ColorScheme.light(error: Color(0xFFB00020)),
        ),
        theme: const ChatImageEditorThemeData(
          primaryColor: Color(0xFF00695C),
          sheetBackgroundColor: Color(0xFFF5F5F5),
          sheetForegroundColor: Color(0xFF1E1E1E),
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
      expect(dialog.backgroundColor, const Color(0xFFF5F5F5));
      expect(textColor(tester, 'Effacer'), const Color(0xFFB00020));
      expect(textColor(tester, 'Continuer'), const Color(0xFF00695C));
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

    testWidgets('is dark with a readable accent over the default sheet', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(platform: TargetPlatform.iOS),
      );

      await closeWithCaption(tester);

      final context = tester.element(find.text('Keep editing'));
      expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
      final theme = scopeOf(tester, find.byTooltip('Close')).theme;
      final keep = textColor(tester, 'Keep editing');
      expect(keep, darkSchemeFor(theme.primaryColor).primary);
      expect(
        contrastRatio(keep, theme.sheetBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
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
