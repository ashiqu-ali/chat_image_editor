import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An editor action that needs a context below the editor's scope, for
/// example to show a dialog or hand the context to a host callback.
typedef EditorAction = Future<void> Function(BuildContext context);

/// Internal wiring between `ChatImageEditor` and its child widgets.
///
/// `ChatImageEditorScope` carries the public configuration; this carries the
/// editor's own callbacks and objects (caption controller, form key, send
/// and close actions) that the built-in widgets need. It isn't exported.
class EditorHost extends InheritedWidget {
  /// Creates the host.
  const EditorHost({
    super.key,
    required this.captionController,
    required this.formKey,
    required this.deleteTargetKey,
    required this.send,
    required this.close,
    required this.sendLongPress,
    required this.sendEnabled,
    required this.takeCaptionAutofocus,
    required super.child,
  });

  /// Holds the caption text in send mode.
  final TextEditingController captionController;

  /// Key of the `Form` around the caption field, used to validate it.
  final GlobalKey<FormState> formKey;

  /// Key of the drag-to-delete target, used to hit-test dragged text.
  final GlobalKey deleteTargetKey;

  /// Validates the caption, exports and completes the editor.
  final EditorAction send;

  /// Closes the editor, asking to discard unsaved work when configured.
  final EditorAction close;

  /// Runs the host's long-press action, or `null` when none is set.
  final EditorAction? sendLongPress;

  /// External switch for the send button, or `null` for always enabled.
  final ValueListenable<bool>? sendEnabled;

  /// Returns whether the caption field should autofocus, and clears that:
  /// `CaptionFieldConfig.autofocus` applies once per editor, when the field
  /// first appears.
  final bool Function() takeCaptionAutofocus;

  /// The nearest host. Throws outside an editor.
  static EditorHost of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<EditorHost>();
    assert(host != null, 'No EditorHost found in context.');
    return host!;
  }

  @override
  bool updateShouldNotify(EditorHost oldWidget) {
    return captionController != oldWidget.captionController ||
        formKey != oldWidget.formKey ||
        deleteTargetKey != oldWidget.deleteTargetKey ||
        send != oldWidget.send ||
        close != oldWidget.close ||
        sendLongPress != oldWidget.sendLongPress ||
        sendEnabled != oldWidget.sendEnabled ||
        takeCaptionAutofocus != oldWidget.takeCaptionAutofocus;
  }
}
