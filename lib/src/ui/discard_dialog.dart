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

/// The default discard confirmation on Android, the web and desktop
/// platforms other than macOS: a Material [AlertDialog] colored from the
/// editor theme.
///
/// "Keep editing" uses the editor's primary color and "Discard" the app
/// theme's `ColorScheme.error`, so the destructive choice stands out.
/// Pops `true` to discard and `false` to keep editing.
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
          style: buttonStyle(theme.primaryColor),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.keepEditing),
        ),
        TextButton(
          style: buttonStyle(Theme.of(context).colorScheme.error),
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
/// `sheetBackgroundColor` (dark by default), and "Keep editing" uses the
/// editor's primary color. Pops `true` to discard and `false` to keep
/// editing.
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
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        brightness: ThemeData.estimateBrightnessForColor(
          theme.sheetBackgroundColor,
        ),
        primaryColor: theme.primaryColor,
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
