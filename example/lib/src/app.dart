import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'chat/chat_screen.dart';

/// Root of the example app.
class ExampleApp extends StatefulWidget {
  /// Creates the app. Pass [settings] to control the appearance from
  /// outside, for example in tests.
  const ExampleApp({super.key, this.settings});

  /// Appearance settings. When `null` the app creates and owns its own.
  final AppSettings? settings;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  AppSettings? _ownSettings;

  AppSettings get _settings =>
      widget.settings ?? (_ownSettings ??= AppSettings());

  @override
  void dispose() {
    _ownSettings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Chat image editor',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: settings.themeFor(Brightness.light),
          darkTheme: settings.themeFor(Brightness.dark),
          home: ChatScreen(settings: settings),
        );
      },
    );
  }
}
