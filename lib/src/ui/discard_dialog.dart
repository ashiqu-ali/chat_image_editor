import 'package:flutter/material.dart';

import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';

/// Shows the themed "discard changes?" dialog and resolves to `true` when
/// the user chooses to discard.
///
/// [context] must be below the editor's `ChatImageEditorScope`.
Future<bool> showDiscardDialog(BuildContext context) async {
  final scope = ChatImageEditorScope.of(context);
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        DiscardDialog(theme: scope.theme, strings: scope.strings),
  );
  return discard ?? false;
}

/// The default discard confirmation, colored from the editor theme.
///
/// Dialogs live in their own route, outside the editor's scope, so the
/// theme and strings are passed in.
class DiscardDialog extends StatelessWidget {
  /// Creates the dialog.
  const DiscardDialog({super.key, required this.theme, required this.strings});

  /// Resolved editor theme.
  final ChatImageEditorResolvedTheme theme;

  /// Editor strings.
  final ChatImageEditorStrings strings;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: theme.primaryColor,
      textStyle: theme.labelStyle,
      minimumSize: const Size(48, 48),
    );
    return AlertDialog(
      backgroundColor: theme.sheetBackgroundColor,
      title: Text(strings.discardTitle, style: theme.sheetTitleStyle),
      content: Text(strings.discardMessage, style: theme.sheetBodyStyle),
      actions: <Widget>[
        TextButton(
          style: buttonStyle,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.keepEditing),
        ),
        TextButton(
          style: buttonStyle,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.discardConfirm),
        ),
      ],
    );
  }
}
