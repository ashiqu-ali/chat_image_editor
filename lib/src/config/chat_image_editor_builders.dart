import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';

/// State handed to a custom send or done button.
@immutable
class SendButtonDetails {
  /// Creates send button details.
  const SendButtonDetails({
    required this.onPressed,
    required this.enabled,
    required this.busy,
    this.onLongPress,
  });

  /// Exports and returns the result. `null` while disabled or busy.
  final VoidCallback? onPressed;

  /// Long-press action, when `ChatImageEditor.onSendLongPress` is set.
  final VoidCallback? onLongPress;

  /// Whether sending is currently allowed.
  final bool enabled;

  /// Whether an export is running.
  final bool busy;
}

/// Builds a replacement send or done button.
typedef SendButtonBuilder =
    Widget Function(BuildContext context, SendButtonDetails details);

/// Builds a replacement for a whole region of the editor. The controller
/// gives full access to the editor state and actions.
typedef EditorRegionBuilder =
    Widget Function(BuildContext context, ChatImageEditorController controller);

/// Builds the view shown when the image fails to load.
typedef EditorErrorBuilder =
    Widget Function(BuildContext context, Object error);

/// Asks the user whether to discard unsaved edits. Return `true` to
/// discard and close the editor, `false` to keep editing.
///
/// [context] is below the editor's `ChatImageEditorScope`, so
/// `ChatImageEditorScope.of(context)` gives the editor's theme and strings.
typedef DiscardConfirmation = Future<bool> Function(BuildContext context);

/// Optional builders that replace parts of the editor UI.
///
/// Anything left `null` uses the built-in, themed widget.
@immutable
class ChatImageEditorBuilders {
  /// Creates builder overrides.
  const ChatImageEditorBuilders({
    this.topBar,
    this.bottomBar,
    this.sendButton,
    this.doneButton,
    this.loading,
    this.error,
    this.confirmDiscard,
  });

  /// Replaces the top bar (close, undo/redo and tool buttons).
  final EditorRegionBuilder? topBar;

  /// Replaces the whole bottom area (caption field and send button, or the
  /// done button).
  final EditorRegionBuilder? bottomBar;

  /// Replaces the send button in send mode.
  final SendButtonBuilder? sendButton;

  /// Replaces the done button in done mode.
  final SendButtonBuilder? doneButton;

  /// Shown while the image decodes.
  final WidgetBuilder? loading;

  /// Shown when the image can't be decoded.
  final EditorErrorBuilder? error;

  /// Replaces the discard confirmation dialog.
  ///
  /// Called when the user closes the editor with unsaved edits or a caption
  /// and `ChatImageEditorConfig.confirmDiscard` is `true`. The default is
  /// adaptive: it follows `Theme.of(context).platform` and shows a
  /// `CupertinoAlertDialog` on iOS and macOS and a Material `AlertDialog`
  /// everywhere else, with the texts from `ChatImageEditorStrings`.
  ///
  /// A builder fully replaces it, for example to always show a Material
  /// dialog:
  ///
  /// ```dart
  /// ChatImageEditorBuilders(
  ///   confirmDiscard: (context) async {
  ///     final strings = ChatImageEditorScope.of(context).strings;
  ///     final discard = await showDialog<bool>(
  ///       context: context,
  ///       builder: (context) => AlertDialog(
  ///         title: Text(strings.discardTitle),
  ///         content: Text(strings.discardMessage),
  ///         actions: [
  ///           TextButton(
  ///             onPressed: () => Navigator.of(context).pop(false),
  ///             child: Text(strings.keepEditing),
  ///           ),
  ///           TextButton(
  ///             onPressed: () => Navigator.of(context).pop(true),
  ///             child: Text(strings.discardConfirm),
  ///           ),
  ///         ],
  ///       ),
  ///     );
  ///     return discard ?? false;
  ///   },
  /// );
  /// ```
  final DiscardConfirmation? confirmDiscard;
}
