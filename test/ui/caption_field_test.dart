import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/editor_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

/// Every tool, opened in turn while the caption bar stays mounted.
const List<EditorTool> _tools = <EditorTool>[
  EditorTool.draw,
  EditorTool.crop,
  EditorTool.compress,
  EditorTool.text,
];

/// Long enough for the bottom controls to slide away, short enough that the
/// compress sheet hasn't started its size estimate.
const Duration _transition = Duration(milliseconds: 250);

/// The caption's `EditableText`, also while it's hidden behind a tool.
EditableText _captionText(WidgetTester tester) {
  return tester.widget<EditableText>(
    find.descendant(
      of: find.byType(TextFormField, skipOffstage: false),
      matching: find.byType(EditableText, skipOffstage: false),
    ),
  );
}

bool _captionFocused(WidgetTester tester) {
  return _captionText(tester).focusNode.hasFocus;
}

/// The translucent chip around the header [label].
Finder _headerChip(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first;
}

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
      testWidgets('focuses the caption when the editor opens', (tester) async {
        await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(autofocus: true),
        );
        expect(_captionFocused(tester), isTrue);
      });

      testWidgets('does not refocus after the draw tool closes', (
        tester,
      ) async {
        final controller = await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(autofocus: true),
        );
        expect(_captionFocused(tester), isTrue);

        await tester.tap(find.byTooltip('Draw'));
        await tester.pumpAndSettle();
        expect(controller.activeTool, EditorTool.draw);
        // Hidden, but still mounted.
        expect(find.byType(TextFormField), findsNothing);
        expect(_captionFocused(tester), isFalse);

        controller.closeTool();
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsOneWidget);
        expect(_captionFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
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
        expect(_captionFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      });

      testWidgets('applies once, even when the field is built again', (
        tester,
      ) async {
        final bytes = testPng();
        final controller = ChatImageEditorController();
        addTearDown(controller.dispose);
        await tester.runAsync(() => controller.load(bytes));
        Future<void> pumpEditor(CaptionFieldConfig captionField) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ChatImageEditor(
                image: bytes,
                controller: controller,
                captionField: captionField,
                onComplete: (_) {},
                onCancel: () {},
              ),
            ),
          );
          await tester.pump();
        }

        await pumpEditor(const CaptionFieldConfig(autofocus: true));
        expect(_captionFocused(tester), isTrue);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await pumpEditor(
          const CaptionFieldConfig(enabled: false, autofocus: true),
        );
        expect(find.byType(TextFormField), findsNothing);
        await pumpEditor(const CaptionFieldConfig(autofocus: true));
        expect(find.byType(TextFormField), findsOneWidget);
        expect(_captionFocused(tester), isFalse);
      });

      testWidgets('stays off by default', (tester) async {
        await pumpReadyEditor(tester);
        expect(_captionFocused(tester), isFalse);
      });
    });

    group('across tools', () {
      testWidgets('opening a tool takes focus and the keyboard away', (
        tester,
      ) async {
        final controller = await pumpReadyEditor(tester);

        for (final tool in _tools) {
          await tester.showKeyboard(find.byType(TextFormField));
          expect(_captionFocused(tester), isTrue, reason: '$tool');
          expect(tester.testTextInput.isVisible, isTrue, reason: '$tool');

          // Opened from the controller, as a host shortcut would, so the top
          // bar's own unfocus doesn't hide a missing one.
          controller.selectTool(tool);
          await tester.pump();
          expect(_captionFocused(tester), isFalse, reason: 'open $tool');
          if (tool != EditorTool.text) {
            // Text entry brings up the keyboard for its own field.
            expect(
              tester.testTextInput.isVisible,
              isFalse,
              reason: 'open $tool',
            );
          }

          await tester.pump(_transition);
          controller.closeTool();
          await tester.pumpAndSettle();
          expect(_captionFocused(tester), isFalse, reason: 'closed $tool');
          expect(
            tester.testTextInput.isVisible,
            isFalse,
            reason: 'closed $tool',
          );
        }
      });

      testWidgets('the caption text survives every tool', (tester) async {
        ChatImageEditorResult? result;
        final controller = await pumpReadyEditor(
          tester,
          onComplete: (value) => result = value,
        );
        await tester.enterText(find.byType(TextFormField), 'See you soon');

        for (final tool in _tools) {
          controller.selectTool(tool);
          await tester.pump();
          await tester.pump(_transition);
          expect(_captionText(tester).controller.text, 'See you soon');
          controller.closeTool();
          await tester.pumpAndSettle();
          expect(find.text('See you soon'), findsOneWidget, reason: '$tool');
        }

        await tester.tap(find.byTooltip('Send'));
        await pumpUntil(tester, () => result != null);
        expect(result?.caption, 'See you soon');
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

    group('layout', () {
      testWidgets('the field spans the bar, the send button below at the end', (
        tester,
      ) async {
        await pumpReadyEditor(tester);

        final screen = tester.getSize(find.byType(Scaffold));
        final field = tester.getRect(find.byType(TextFormField));
        final send = tester.getRect(find.byTooltip('Send'));
        expect(field.left, lessThanOrEqualTo(16));
        expect(field.right, greaterThanOrEqualTo(screen.width - 16));
        expect(send.top, greaterThanOrEqualTo(field.bottom));
        expect(send.right, moreOrLessEquals(field.right));
      });

      testWidgets('the header chip sits below the field, left of send', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(
            header: Text('Sending to Sam'),
          ),
        );

        final field = tester.getRect(find.byType(TextFormField));
        final chip = tester.getRect(_headerChip('Sending to Sam'));
        final send = tester.getRect(find.byTooltip('Send'));
        expect(chip.top, greaterThanOrEqualTo(field.bottom));
        expect(chip.left, moreOrLessEquals(field.left));
        expect(chip.right, lessThan(send.left));
        expect(chip.center.dy, moreOrLessEquals(send.center.dy));
        expect(send.right, moreOrLessEquals(field.right));
      });

      testWidgets('a long header stays on one line, ellipsized', (
        tester,
      ) async {
        final header = 'Sending to ${'the whole extended family ' * 8}';
        await pumpReadyEditor(
          tester,
          captionField: CaptionFieldConfig(header: Text(header)),
        );

        expect(tester.takeException(), isNull);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(header),
        );
        expect(paragraph.maxLines, 1);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(paragraph.didExceedMaxLines, isTrue);
        final chip = tester.getRect(_headerChip(header));
        final send = tester.getRect(find.byTooltip('Send'));
        expect(chip.right, lessThanOrEqualTo(send.left));
        expect(chip.height, lessThan(send.height));
      });

      testWidgets('rides above the keyboard without resizing the image', (
        tester,
      ) async {
        await pumpReadyEditor(
          tester,
          captionField: const CaptionFieldConfig(
            header: Text('Sending to Sam'),
          ),
        );
        final screen = tester.getSize(find.byType(Scaffold));
        final canvas = tester.getRect(find.byType(EditorCanvas));

        const keyboard = 300.0;
        tester.view.viewInsets = FakeViewPadding(
          bottom: keyboard * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final send = tester.getRect(find.byTooltip('Send'));
        expect(send.bottom, lessThanOrEqualTo(screen.height - keyboard));
        expect(
          tester.getRect(find.text('Sending to Sam')).bottom,
          lessThanOrEqualTo(screen.height - keyboard),
        );
        expect(tester.getRect(find.byType(EditorCanvas)), canvas);
      });
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
