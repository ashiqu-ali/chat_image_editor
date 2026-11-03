import 'package:flutter/material.dart';

/// A named seed color offered by the appearance switcher.
@immutable
class SeedOption {
  /// Creates a seed option.
  const SeedOption(this.name, this.color);

  /// Label shown in the tooltip and read by screen readers.
  final String name;

  /// Seed for `ColorScheme.fromSeed`.
  final Color color;
}

/// App-wide appearance: light or dark mode and the seed color.
///
/// The editor isn't told about any of this. It resolves its colors from the
/// app's `ThemeData`, so changing these values restyles it automatically.
class AppSettings extends ChangeNotifier {
  /// Creates settings, starting with the system brightness and the first
  /// seed color.
  AppSettings({ThemeMode themeMode = ThemeMode.system, Color? seedColor})
    : _themeMode = themeMode,
      _seedColor = seedColor ?? seedOptions.first.color;

  /// Seed colors offered on the home screen.
  static const List<SeedOption> seedOptions = <SeedOption>[
    SeedOption('Teal', Color(0xFF00897B)),
    SeedOption('Indigo', Color(0xFF3949AB)),
    SeedOption('Orange', Color(0xFFF4511E)),
    SeedOption('Pink', Color(0xFFD81B60)),
    SeedOption('Purple', Color(0xFF8E24AA)),
  ];

  ThemeMode _themeMode;
  Color _seedColor;

  /// Light, dark, or follow the system.
  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
  }

  /// Seed of the app's color scheme.
  Color get seedColor => _seedColor;

  set seedColor(Color value) {
    if (value == _seedColor) return;
    _seedColor = value;
    notifyListeners();
  }

  /// The app theme for [brightness].
  ThemeData themeFor(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
    );
  }
}
