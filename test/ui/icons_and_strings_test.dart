import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('custom icons', () {
    testWidgets('replace the defaults', (tester) async {
      await pumpReadyEditor(
        tester,
        icons: const ChatImageEditorIcons(
          send: Icon(Icons.arrow_upward),
          close: Icon(Icons.arrow_back),
          crop: Icon(Icons.aspect_ratio),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.aspect_ratio), findsOneWidget);
      expect(find.byIcon(Icons.crop_rotate), findsNothing);
    });

    testWidgets('inherit the themed color and size', (tester) async {
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(
          sendButtonForegroundColor: Color(0xFF123456),
          foregroundColor: Color(0xFFABCDEF),
          iconSize: 30,
        ),
        icons: const ChatImageEditorIcons(
          send: Icon(Icons.arrow_upward),
          close: Icon(Icons.arrow_back),
        ),
      );

      final sendIcon = IconTheme.of(
        tester.element(find.byIcon(Icons.arrow_upward)),
      );
      expect(sendIcon.color, const Color(0xFF123456));
      expect(sendIcon.size, 30);

      final closeIcon = IconTheme.of(
        tester.element(find.byIcon(Icons.arrow_back)),
      );
      expect(closeIcon.color, const Color(0xFFABCDEF));
    });

    testWidgets('any widget can be an icon', (tester) async {
      await pumpReadyEditor(
        tester,
        icons: const ChatImageEditorIcons(
          send: Text('GO', key: ValueKey<String>('send-label')),
        ),
      );

      expect(find.byKey(const ValueKey<String>('send-label')), findsOneWidget);
    });
  });

  group('custom strings', () {
    testWidgets('are used for hints and tooltips', (tester) async {
      await pumpReadyEditor(
        tester,
        strings: const ChatImageEditorStrings(
          captionHint: 'Ajouter une légende',
          send: 'Envoyer',
          close: 'Fermer',
          undo: 'Annuler',
          draw: 'Dessiner',
        ),
      );

      expect(find.text('Ajouter une légende'), findsOneWidget);
      expect(find.byTooltip('Envoyer'), findsOneWidget);
      expect(find.byTooltip('Fermer'), findsOneWidget);
      expect(find.byTooltip('Annuler'), findsOneWidget);
      expect(find.byTooltip('Dessiner'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      expect(find.text('Add a caption…'), findsNothing);
    });

    testWidgets('label the tools in config order', (tester) async {
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(
          tools: <EditorTool>[EditorTool.draw, EditorTool.text],
        ),
      );

      expect(find.byTooltip('Draw'), findsOneWidget);
      expect(find.byTooltip('Text'), findsOneWidget);
      expect(find.byTooltip('Crop and rotate'), findsNothing);
      expect(find.byTooltip('Image quality'), findsNothing);
      final drawX = tester.getCenter(find.byTooltip('Draw')).dx;
      final textX = tester.getCenter(find.byTooltip('Text')).dx;
      expect(drawX, lessThan(textX));
    });

    testWidgets('undo and redo hide when showUndoRedo is off', (tester) async {
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(showUndoRedo: false),
      );

      expect(find.byTooltip('Undo'), findsNothing);
      expect(find.byTooltip('Redo'), findsNothing);
    });

    testWidgets('label the compress sheet', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpReadyEditor(
        tester,
        strings: ChatImageEditorStrings(
          compress: 'Calidad de la imagen',
          qualityLabel: 'Calidad',
          originalSizeLabel: 'Original',
          estimatedSizeLabel: 'Tamaño estimado',
          estimatingSize: 'Calculando…',
          apply: 'Aplicar',
          formatQuality: (quality) => 'Q$quality',
          formatBytes: (bytes) => '$bytes octetos',
        ),
      );

      await tester.tap(find.byTooltip('Calidad de la imagen'));
      await tester.pump();
      expect(find.text('Calidad de la imagen'), findsWidgets);
      expect(find.text('Calidad'), findsOneWidget);
      expect(find.text('Q90'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);
      expect(find.text('Apply'), findsNothing);
      expect(find.textContaining('octetos'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Tamaño estimado')).label,
        'Tamaño estimado\nCalculando…',
      );

      // Let the estimate finish before the editor goes away.
      await tester.pump(const Duration(milliseconds: 350));
      await pumpUntil(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      expect(find.textContaining('octetos'), findsNWidgets(2));
      semantics.dispose();
    });
  });

  group('default strings', () {
    test('name the new controls in English', () {
      const strings = ChatImageEditorStrings();
      expect(strings.color, 'Color');
      expect(strings.apply, 'Apply');
      expect(
        strings.formatQuality,
        ChatImageEditorStrings.defaultFormatQuality,
      );
      expect(strings.formatQuality(90), 'High · 90');
      expect(strings.colorLabel, ChatImageEditorStrings.defaultColorLabel);
      expect(
        strings.colorLabel(const Color(0xFFFF0000), 2, 10),
        'Color 3 of 10',
      );
      expect(strings.formatBytes(1536), '1.5 KB');
    });

    test('defaultFormatQuality names a tier at each boundary', () {
      const format = ChatImageEditorStrings.defaultFormatQuality;
      expect(format(1), 'Low · 1');
      expect(format(10), 'Low · 10');
      expect(format(40), 'Low · 40');
      expect(format(41), 'Medium · 41');
      expect(format(75), 'Medium · 75');
      expect(format(76), 'High · 76');
      expect(format(85), 'High · 85');
      expect(format(100), 'High · 100');
    });
  });
}
