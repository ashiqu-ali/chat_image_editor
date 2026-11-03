import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  const appPrimary = Color(0xFF00796B);
  const extensionColor = Color(0xFF5E35B1);
  const overrideColor = Color(0xFFD81B60);

  ThemeData appTheme({List<ThemeExtension<dynamic>> extensions = const []}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appPrimary,
      ).copyWith(primary: appPrimary, onPrimary: const Color(0xFFFFFFFF)),
      extensions: extensions,
    );
  }

  group('theming', () {
    testWidgets('accent defaults to the app ColorScheme.primary', (
      tester,
    ) async {
      await pumpReadyEditor(tester, appTheme: appTheme());

      expect(buttonColor(tester, 'Send'), appPrimary);
      final theme = scopeOf(tester, find.byTooltip('Send')).theme;
      expect(theme.primaryColor, appPrimary);
      expect(theme.sendButtonColor, appPrimary);
      expect(theme.activeToolColor, appPrimary);
      expect(theme.sliderActiveColor, appPrimary);
    });

    testWidgets('the default draw color follows the accent', (tester) async {
      final controller = await pumpReadyEditor(tester, appTheme: appTheme());

      expect(controller.drawColor, appPrimary);
      expect(controller.textColor, const Color(0xFFFFFFFF));
    });

    testWidgets('the export uses the theme text layer style', (tester) async {
      const style = TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        shadows: <Shadow>[Shadow(blurRadius: 4, color: Color(0x66000000))],
      );
      final controller = await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(textLayerStyle: style),
      );

      final theme = scopeOf(tester, find.byTooltip('Send')).theme;
      expect(theme.textLayerStyle, style);
      expect(controller.textLayerStyle, style);
    });

    testWidgets('a ThemeExtension on the app theme is honoured', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: appTheme(
          extensions: const <ThemeExtension<dynamic>>[
            ChatImageEditorThemeData(
              primaryColor: extensionColor,
              backgroundColor: Color(0xFF101010),
            ),
          ],
        ),
      );

      expect(buttonColor(tester, 'Send'), extensionColor);
      final theme = scopeOf(tester, find.byTooltip('Send')).theme;
      expect(theme.activeToolColor, extensionColor);
      expect(theme.backgroundColor, const Color(0xFF101010));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF101010));
    });

    testWidgets('the theme passed to the editor wins over the extension', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(
        tester,
        appTheme: appTheme(
          extensions: const <ThemeExtension<dynamic>>[
            ChatImageEditorThemeData(
              sendButtonColor: extensionColor,
              defaultDrawColor: extensionColor,
            ),
          ],
        ),
        theme: const ChatImageEditorThemeData(
          sendButtonColor: overrideColor,
          defaultDrawColor: overrideColor,
        ),
      );

      expect(buttonColor(tester, 'Send'), overrideColor);
      expect(controller.drawColor, overrideColor);
      // Fields the override leaves out still come from the app.
      final theme = scopeOf(tester, find.byTooltip('Send')).theme;
      expect(theme.primaryColor, appPrimary);
    });

    group('text style overrides merge onto the themed defaults', () {
      testWidgets('a colorless caption style keeps captionTextColor', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          appTheme: ThemeData(brightness: Brightness.light),
          theme: const ChatImageEditorThemeData(
            captionStyle: TextStyle(fontSize: 18),
            captionTextColor: Color(0xFFFFFFFF),
          ),
        );

        final theme = scopeOf(tester, find.byTooltip('Send')).theme;
        expect(theme.captionStyle.fontSize, 18);
        expect(theme.captionStyle.color, const Color(0xFFFFFFFF));
        final text = tester.widget<EditableText>(find.byType(EditableText));
        expect(text.style.color, const Color(0xFFFFFFFF));
        expect(text.style.fontSize, 18);
      });

      testWidgets('sheet and label styles keep their themed colors', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          appTheme: ThemeData(brightness: Brightness.light),
          theme: const ChatImageEditorThemeData(
            sheetForegroundColor: Color(0xFFEEEEEE),
            foregroundColor: Color(0xFFDDDDDD),
            sheetTitleStyle: TextStyle(fontWeight: FontWeight.w700),
            sheetBodyStyle: TextStyle(fontSize: 13),
            labelStyle: TextStyle(letterSpacing: 1.5),
          ),
        );

        final theme = scopeOf(tester, find.byTooltip('Send')).theme;
        expect(theme.sheetTitleStyle.fontWeight, FontWeight.w700);
        expect(theme.sheetTitleStyle.color, const Color(0xFFEEEEEE));
        expect(theme.sheetBodyStyle.fontSize, 13);
        expect(theme.sheetBodyStyle.color, const Color(0xFFEEEEEE));
        expect(theme.labelStyle.letterSpacing, 1.5);
        expect(theme.labelStyle.color, const Color(0xFFDDDDDD));

        await tester.tap(find.byTooltip('Image quality'));
        await tester.pump();
        final title = tester.widget<Text>(find.text('Image quality').last);
        expect(title.style?.color, const Color(0xFFEEEEEE));
        expect(title.style?.fontWeight, FontWeight.w700);
      });

      testWidgets('a color in the override still wins', (tester) async {
        await pumpReadyEditor(
          tester,
          theme: const ChatImageEditorThemeData(
            captionStyle: TextStyle(color: Color(0xFF00FF00)),
            sheetTitleStyle: TextStyle(color: Color(0xFF0000FF)),
          ),
        );

        final theme = scopeOf(tester, find.byTooltip('Send')).theme;
        expect(theme.captionStyle.color, const Color(0xFF00FF00));
        expect(theme.sheetTitleStyle.color, const Color(0xFF0000FF));
      });
    });

    testWidgets('a disabled send button uses the disabled color', (
      tester,
    ) async {
      final enabled = ValueNotifier<bool>(false);
      addTearDown(enabled.dispose);
      await pumpReadyEditor(
        tester,
        appTheme: appTheme(),
        theme: const ChatImageEditorThemeData(
          sendButtonDisabledColor: Color(0xFF333333),
        ),
        sendEnabled: enabled,
      );

      expect(buttonColor(tester, 'Send'), const Color(0xFF333333));

      enabled.value = true;
      await tester.pump();
      expect(buttonColor(tester, 'Send'), appPrimary);
    });
  });
}
