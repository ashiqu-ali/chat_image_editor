import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/app.dart';
import 'package:chat_image_editor_example/src/app_settings.dart';
import 'package:chat_image_editor_example/src/demos/demo.dart';
import 'package:chat_image_editor_example/src/demos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the demos screen from the chat's app bar.
Future<void> openDemos(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Customization demos'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demos screen lists every demo without opening the editor', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    await openDemos(tester);

    expect(find.byType(DemosScreen), findsOneWidget);
    expect(find.text('Sample image'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    for (final demo in editorDemos) {
      await tester.scrollUntilVisible(find.text(demo.title), 200);
      expect(find.text(demo.title), findsOneWidget);
    }

    expect(find.byType(ChatImageEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance controls restyle the app', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(ExampleApp(settings: settings));
    await tester.pumpAndSettle();
    await openDemos(tester);

    ThemeData currentTheme() => Theme.of(tester.element(find.byType(AppBar)));

    await tester.scrollUntilVisible(find.text('Dark'), 200);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(currentTheme().brightness, Brightness.dark);

    final primaryBefore = currentTheme().colorScheme.primary;
    final pink = AppSettings.seedOptions.firstWhere(
      (option) => option.name == 'Pink',
    );
    await tester.scrollUntilVisible(find.byTooltip(pink.name), 200);
    await tester.tap(find.byTooltip(pink.name));
    await tester.pumpAndSettle();
    expect(settings.seedColor, pink.color);
    expect(currentTheme().colorScheme.primary, isNot(primaryBefore));

    expect(find.byType(ChatImageEditor), findsNothing);
  });
}
