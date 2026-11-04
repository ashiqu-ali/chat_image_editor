import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';

/// Shows the default "discard changes?" confirmation and resolves to `true`
/// when the user chooses to discard.
///
/// The dialog matches the platform reported by `Theme.of(context).platform`,
/// so an app (or a test) can override it through its `ThemeData`:
///
/// - iOS and macOS: a [CupertinoDiscardDialog]. Like a native alert, it
///   closes only through one of its actions.
/// - everywhere else: a [MaterialDiscardDialog]. A barrier tap or the back
///   button dismisses it and counts as "keep editing".
///
/// [context] must be below the editor's `ChatImageEditorScope`.
Future<bool> showDiscardDialog(BuildContext context) async {
  final scope = ChatImageEditorScope.of(context);
  final theme = scope.theme;
  final strings = scope.strings;
  final discard = await switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoDiscardDialog(theme: theme, strings: strings),
    ),
    _ => showDialog<bool>(
      context: context,
      builder: (_) => MaterialDiscardDialog(theme: theme, strings: strings),
    ),
  };
  return discard ?? false;
}

/// A dark color scheme seeded with the editor's primary color when
/// [theme]'s sheet is dark, or `null` when it is light.
///
/// The app's accents are tuned for the app's own surfaces, so a light app's
/// primary and error colors are hard to read on the editor's dark sheet.
/// The dark scheme keeps the accent's hue at a tone that stays readable.
ColorScheme? _darkSheetScheme(ChatImageEditorResolvedTheme theme) {
  final brightness = ThemeData.estimateBrightnessForColor(
    theme.sheetBackgroundColor,
  );
  if (brightness != Brightness.dark) return null;
  return ColorScheme.fromSeed(
    seedColor: theme.primaryColor,
    brightness: Brightness.dark,
  );
}

/// The default discard confirmation on Android, the web and desktop
/// platforms other than macOS: a Material [AlertDialog] colored from the
/// editor theme.
///
/// On a light sheet, "Keep editing" uses the editor's primary color and
/// "Discard" the app theme's `ColorScheme.error`, so the destructive choice
/// stands out. On a dark sheet (the default) both come from a dark color
/// scheme seeded with the editor's primary color instead, so they stay
/// readable whatever the app's brightness. Pops `true` to discard and
/// `false` to keep editing.
///
/// Dialogs live in their own route, outside the editor's scope, so the
/// theme and strings are passed in.
class MaterialDiscardDialog extends StatelessWidget {
  /// Creates the dialog.
  const MaterialDiscardDialog({
    super.key,
    required this.theme,
    required this.strings,
  });

  /// Resolved editor theme.
  final ChatImageEditorResolvedTheme theme;

  /// Editor strings.
  final ChatImageEditorStrings strings;

  @override
  Widget build(BuildContext context) {
    final darkScheme = _darkSheetScheme(theme);
    final keepColor = darkScheme?.primary ?? theme.primaryColor;
    final discardColor =
        darkScheme?.error ?? Theme.of(context).colorScheme.error;
    ButtonStyle buttonStyle(Color color) => TextButton.styleFrom(
      foregroundColor: color,
      textStyle: theme.labelStyle,
      minimumSize: const Size(48, 48),
    );
    return AlertDialog(
      backgroundColor: theme.sheetBackgroundColor,
      title: Text(strings.discardTitle, style: theme.sheetTitleStyle),
      content: Text(strings.discardMessage, style: theme.sheetBodyStyle),
      actions: <Widget>[
        TextButton(
          style: buttonStyle(keepColor),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.keepEditing),
        ),
        TextButton(
          style: buttonStyle(discardColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.discardConfirm),
        ),
      ],
    );
  }
}

/// The default discard confirmation on iOS and macOS: a
/// [CupertinoAlertDialog] with "Keep editing" as the default action and
/// "Discard" as the destructive one.
///
/// The alert is light or dark to match the editor's
/// `sheetBackgroundColor` (dark by default). "Keep editing" uses the
/// editor's primary color on a light alert and, like the Material dialog,
/// the primary of a dark scheme seeded with it on a dark one. "Discard"
/// uses the system red. Pops `true` to discard and `false` to keep editing.
///
/// Dialogs live in their own route, outside the editor's scope, so the
/// theme and strings are passed in.
class CupertinoDiscardDialog extends StatelessWidget {
  /// Creates the dialog.
  const CupertinoDiscardDialog({
    super.key,
    required this.theme,
    required this.strings,
  });

  /// Resolved editor theme.
  final ChatImageEditorResolvedTheme theme;

  /// Editor strings.
  final ChatImageEditorStrings strings;

  @override
  Widget build(BuildContext context) {
    final darkScheme = _darkSheetScheme(theme);
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        brightness: darkScheme == null ? Brightness.light : Brightness.dark,
        primaryColor: darkScheme?.primary ?? theme.primaryColor,
      ),
      child: CupertinoAlertDialog(
        title: Text(strings.discardTitle),
        content: Text(strings.discardMessage),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.keepEditing),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.discardConfirm),
          ),
        ],
      ),
    );
  }
}
