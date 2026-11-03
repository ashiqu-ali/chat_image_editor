import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('caption field', () {
    testWidgets('maps the config onto the TextFormField', (tester) async {
      final formatter = FilteringTextInputFormatter.deny(RegExp('[0-9]'));
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(primaryColor: Color(0xFF00897B)),
        captionField: CaptionFieldConfig(
          maxLength: 20,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          inputFormatters: <TextInputFormatter>[formatter],
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 20);
      expect(field.minLines, 1);
      expect(field.maxLines, 3);
      expect(field.keyboardType, TextInputType.text);
      expect(field.textInputAction, TextInputAction.done);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.inputFormatters, contains(formatter));
      expect(field.cursorColor, const Color(0xFF00897B));
      expect(field.decoration?.hintText, 'Add a caption…');
      expect(field.decoration?.filled, isTrue);
    });

    testWidgets('a custom decoration gets the localized hint', (tester) async {
      await pumpReadyEditor(
        tester,
        strings: const ChatImageEditorStrings(captionHint: 'Légende'),
        captionField: const CaptionFieldConfig(
          decoration: InputDecoration(border: UnderlineInputBorder()),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'Légende');
      expect(field.decoration?.border, isA<UnderlineInputBorder>());
    });

    testWidgets('style and cursor color overrides apply', (tester) async {
      const style = TextStyle(fontSize: 21, color: Color(0xFF00FF00));
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(
          style: style,
          cursorColor: Color(0xFFFF0000),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontSize, 21);
      expect(field.style?.color, const Color(0xFF00FF00));
      expect(field.cursorColor, const Color(0xFFFF0000));
    });

    testWidgets('a style without a color keeps the themed caption color', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        appTheme: ThemeData(brightness: Brightness.light),
        captionField: const CaptionFieldConfig(style: TextStyle(fontSize: 20)),
      );

      final theme = scopeOf(tester, find.byType(TextFormField)).theme;
      final text = tester.widget<EditableText>(find.byType(EditableText));
      expect(text.style.fontSize, 20);
      expect(text.style.color, theme.captionTextColor);
      expect(text.style.color, const Color(0xFFFFFFFF));
    });

    group('autofocus', () {
      bool captionFocused(WidgetTester tester) {
        final text = find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(EditableText),
        );
        return tester.widget<EditableText>(text).focusNode.hasFocus;
      }

      testWidgets('focuses the caption when the editor opens', (tester) async {
        await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(autofocus: true),
        );
        expect(captionFocused(tester), isTrue);
      });

      testWidgets('does not refocus after the draw tool closes', (
        tester,
      ) async {
        final controller = await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(autofocus: true),
        );
        expect(captionFocused(tester), isTrue);

        await tester.tap(find.byTooltip('Draw'));
        await tester.pump();
        expect(find.byType(TextFormField), findsNothing);

        controller.closeTool();
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsOneWidget);
        expect(captionFocused(tester), isFalse);
      });

      testWidgets('does not refocus after text entry finishes', (tester) async {
        final controller = await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(autofocus: true),
        );

        await tester.tap(find.byTooltip('Text'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Hi');
        await tester.tap(find.byTooltip('Done'));
        await tester.pumpAndSettle();
        expect(controller.editingTextId, isNull);

        expect(find.byType(TextFormField), findsOneWidget);
        expect(captionFocused(tester), isFalse);
      });

      testWidgets('stays off by default', (tester) async {
        await pumpReadyEditor(tester);
        expect(captionFocused(tester), isFalse);
      });
    });

    testWidgets('uses an external controller and reports changes', (
      tester,
    ) async {
      final captionController = TextEditingController(text: 'Hello');
      addTearDown(captionController.dispose);
      final changes = <String>[];
      await pumpReadyEditor(
        tester,
        captionField: CaptionFieldConfig(
          controller: captionController,
          onChanged: changes.add,
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Hi there');
      expect(captionController.text, 'Hi there');
      expect(changes, <String>['Hi there']);
    });

    testWidgets('starts from initialValue', (tester) async {
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(initialValue: 'Prefilled'),
      );

      expect(find.text('Prefilled'), findsOneWidget);
    });

    testWidgets('shows the header above the field', (tester) async {
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(header: Text('Sending to Sam')),
      );

      expect(find.text('Sending to Sam'), findsOneWidget);
      final headerY = tester.getCenter(find.text('Sending to Sam')).dy;
      final fieldY = tester.getCenter(find.byType(TextFormField)).dy;
      expect(headerY, lessThan(fieldY));
    });

    testWidgets('can be turned off, leaving the send button', (tester) async {
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(
          enabled: false,
          header: Text('Hidden header'),
        ),
      );

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Hidden header'), findsNothing);
      expect(find.byTooltip('Send'), findsOneWidget);
    });

    testWidgets('a failing validator blocks sending', (tester) async {
      var completed = false;
      await pumpReadyEditor(
        tester,
        captionField: CaptionFieldConfig(
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Caption required' : null,
        ),
        onComplete: (_) => completed = true,
      );

      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(find.text('Caption required'), findsOneWidget);
      expect(completed, isFalse);
    });
  });
}
