import 'package:flutter/material.dart';

import '../app_settings.dart';

/// Switches the app between light and dark and picks its seed color.
class AppearanceCard extends StatelessWidget {
  /// Creates the card for [settings].
  const AppearanceCard({super.key, required this.settings});

  /// Settings to read and update.
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Brightness', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (selection) {
                      settings.themeMode = selection.single;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text('Seed color', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'The Default demo has no theme of its own, so its accent '
                  'follows this choice.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final option in AppSettings.seedOptions)
                      _SeedSwatch(
                        option: option,
                        selected: option.color == settings.seedColor,
                        onTap: () => settings.seedColor = option.color,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SeedOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    final check =
        ThemeData.estimateBrightnessForColor(option.color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: option.name,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: option.name,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? ring : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected ? Icon(Icons.check, size: 20, color: check) : null,
          ),
        ),
      ),
    );
  }
}
