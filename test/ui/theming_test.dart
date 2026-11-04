import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/top_bar.dart';
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

    group('floating controls', () {
      testWidgets('default to translucent black, so the photo shows through', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(
            header: Text('Sending to Sam'),
          ),
        );

        final theme = scopeOf(tester, find.byTooltip('Send')).theme;
        expect(theme.toolbarBackgroundColor, const Color(0x8A000000));
        expect(theme.captionFillColor, const Color(0x8A000000));
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.fillColor, theme.captionFillColor);
        expect(field.decoration!.fillColor!.a, lessThan(1));
        expect(
          _chipColor(tester, 'Sending to Sam'),
          theme.toolbarBackgroundColor,
        );
      });

      testWidgets('the caption fill and header chip follow the theme', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          theme: const ChatImageEditorThemeData(
            captionFillColor: Color(0x66102030),
            toolbarBackgroundColor: Color(0x80123456),
          ),
          captionField: const CaptionFieldConfig(
            header: Text('Sending to Sam'),
          ),
        );

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.fillColor, const Color(0x66102030));
        expect(_chipColor(tester, 'Sending to Sam'), const Color(0x80123456));
      });

      testWidgets('the selected tool is drawn in activeToolColor, unfilled', (
        tester,
      ) async {
        const active = Color(0xFFFFD180);
        final controller = await pumpReadyEditor(
          tester,
          theme: const ChatImageEditorThemeData(activeToolColor: active),
        );
        final theme = scopeOf(tester, find.byTooltip('Send')).theme;

        await tester.tap(find.byTooltip('Image quality'));
        await tester.pump();
        expect(controller.activeTool, EditorTool.compress);

        Finder tool(String tooltip) => find.descendant(
          of: find.byType(EditorTopBar),
          matching: find.byTooltip(tooltip),
        );
        Color? iconColor(Finder button) => IconTheme.of(
          tester.element(
            find.descendant(of: button, matching: find.byType(Icon)),
          ),
        ).color;

        final selected = tool('Image quality');
        expect(iconColor(selected), active);
        expect(iconColor(tool('Draw')), theme.foregroundColor);
        // The usual backdrop, not a circle filled with the accent.
        expect(_fillsWith(selected, active), findsNothing);
        expect(
          _fillsWith(selected, theme.toolbarBackgroundColor),
          findsOneWidget,
        );

        controller.closeTool();
        await tester.pumpAndSettle();
      });
    });

    testWidgets('sendButtonSize sets the send button diameter', (tester) async {
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(sendButtonSize: 60),
      );

      final button = find
          .descendant(
            of: find.byTooltip('Send'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(button), const Size.square(60));
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

  group('ChatImageEditorThemeData', () {
    test('merge, copyWith and lerp carry every field', () {
      final a = _fullTheme(1);
      final b = _fullTheme(2);
      const empty = ChatImageEditorThemeData();

      expect(_fields(empty), everyElement(isNull));
      expect(_fields(empty.merge(a)), _fields(a));
      expect(_fields(a.merge(b)), _fields(b));
      expect(_fields(a.merge(empty)), _fields(a));
      expect(_fields(a.merge(null)), _fields(a));
      expect(_fields(a.copyWith()), _fields(a));
      expect(_fields(a.lerp(b, 0)), _fields(a));
      expect(_fields(a.lerp(b, 1)), _fields(b));
    });

    testWidgets('resolve takes every field from the override', (tester) async {
      final override = _fullTheme(1);
      late ChatImageEditorResolvedTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = ChatImageEditorThemeData.resolve(context, override);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Text styles are merged onto the themed defaults, so compare the
      // size each override sets.
      final expected = _fields(
        override,
      ).map((value) => value is TextStyle ? value.fontSize : value).toList();
      expect(_resolvedFields(resolved), expected);
    });
  });
}

/// Background color of the header chip around [label].
Color? _chipColor(WidgetTester tester, String label) {
  final chip = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (chip.decoration as BoxDecoration).color;
}

/// Boxes and materials under [finder] filled with [color].
Finder _fillsWith(Finder finder, Color color) {
  return find.descendant(
    of: finder,
    matching: find.byWidgetPredicate((widget) {
      if (widget is Material) return widget.color == color;
      if (widget is DecoratedBox) {
        final decoration = widget.decoration;
        return decoration is BoxDecoration && decoration.color == color;
      }
      return false;
    }),
  );
}

/// A theme with every field set to a value unique to [seed].
ChatImageEditorThemeData _fullTheme(int seed) {
  Color c(int index) => Color(0xFF000000 + seed * 0x10000 + index);
  return ChatImageEditorThemeData(
    primaryColor: c(1),
    onPrimaryColor: c(2),
    backgroundColor: c(3),
    foregroundColor: c(4),
    toolbarBackgroundColor: c(5),
    activeToolColor: c(6),
    scrimColor: c(7),
    cropFrameColor: c(8),
    cropHandleColor: c(9),
    cropGridColor: c(10),
    cropOverlayColor: c(11),
    sliderActiveColor: c(12),
    sliderInactiveColor: c(13),
    sliderThumbColor: c(14),
    deleteTargetColor: c(15),
    deleteTargetActiveColor: c(16),
    guideLineColor: c(17),
    captionFillColor: c(18),
    captionTextColor: c(19),
    captionHintColor: c(20),
    sendButtonColor: c(21),
    sendButtonForegroundColor: c(22),
    sendButtonDisabledColor: c(23),
    sheetBackgroundColor: c(24),
    sheetForegroundColor: c(25),
    defaultDrawColor: c(26),
    defaultTextColor: c(27),
    loadingIndicatorColor: c(28),
    palette: <Color>[c(29), c(30)],
    labelStyle: TextStyle(fontSize: 10.0 + seed),
    captionStyle: TextStyle(fontSize: 12.0 + seed),
    sheetTitleStyle: TextStyle(fontSize: 14.0 + seed),
    sheetBodyStyle: TextStyle(fontSize: 16.0 + seed),
    textLayerStyle: TextStyle(fontSize: 18.0 + seed),
    iconSize: 20.0 + seed,
    captionBorderRadius: BorderRadius.circular(4.0 + seed),
    sendButtonSize: 40.0 + seed,
  );
}

/// Every field of [t], in declaration order.
List<Object?> _fields(ChatImageEditorThemeData t) => <Object?>[
  t.primaryColor,
  t.onPrimaryColor,
  t.backgroundColor,
  t.foregroundColor,
  t.toolbarBackgroundColor,
  t.activeToolColor,
  t.scrimColor,
  t.cropFrameColor,
  t.cropHandleColor,
  t.cropGridColor,
  t.cropOverlayColor,
  t.sliderActiveColor,
  t.sliderInactiveColor,
  t.sliderThumbColor,
  t.deleteTargetColor,
  t.deleteTargetActiveColor,
  t.guideLineColor,
  t.captionFillColor,
  t.captionTextColor,
  t.captionHintColor,
  t.sendButtonColor,
  t.sendButtonForegroundColor,
  t.sendButtonDisabledColor,
  t.sheetBackgroundColor,
  t.sheetForegroundColor,
  t.defaultDrawColor,
  t.defaultTextColor,
  t.loadingIndicatorColor,
  t.palette,
  t.labelStyle,
  t.captionStyle,
  t.sheetTitleStyle,
  t.sheetBodyStyle,
  t.textLayerStyle,
  t.iconSize,
  t.captionBorderRadius,
  t.sendButtonSize,
];

/// The fields of [t] in the order of [_fields], text styles as font sizes.
List<Object?> _resolvedFields(ChatImageEditorResolvedTheme t) => <Object?>[
  t.primaryColor,
  t.onPrimaryColor,
  t.backgroundColor,
  t.foregroundColor,
  t.toolbarBackgroundColor,
  t.activeToolColor,
  t.scrimColor,
  t.cropFrameColor,
  t.cropHandleColor,
  t.cropGridColor,
  t.cropOverlayColor,
  t.sliderActiveColor,
  t.sliderInactiveColor,
  t.sliderThumbColor,
  t.deleteTargetColor,
  t.deleteTargetActiveColor,
  t.guideLineColor,
  t.captionFillColor,
  t.captionTextColor,
  t.captionHintColor,
  t.sendButtonColor,
  t.sendButtonForegroundColor,
  t.sendButtonDisabledColor,
  t.sheetBackgroundColor,
  t.sheetForegroundColor,
  t.defaultDrawColor,
  t.defaultTextColor,
  t.loadingIndicatorColor,
  t.palette,
  t.labelStyle.fontSize,
  t.captionStyle.fontSize,
  t.sheetTitleStyle.fontSize,
  t.sheetBodyStyle.fontSize,
  t.textLayerStyle.fontSize,
  t.iconSize,
  t.captionBorderRadius,
  t.sendButtonSize,
];
