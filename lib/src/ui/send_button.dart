import 'package:flutter/material.dart';

import '../config/chat_image_editor_builders.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'controller_selector.dart';
import 'editor_host.dart';

/// The default circular send (or done) button.
///
/// Shows [icon] normally and a progress indicator while [details] is busy.
class EditorSendButton extends StatelessWidget {
  /// Creates the button.
  const EditorSendButton({
    super.key,
    required this.details,
    required this.icon,
    required this.tooltip,
  });

  /// State and callbacks.
  final SendButtonDetails details;

  /// Icon shown when idle.
  final Widget icon;

  /// Tooltip and semantics label.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    final size = theme.sendButtonSize;
    final color = details.enabled
        ? theme.sendButtonColor
        : theme.sendButtonDisabledColor;
    final hit = size < 48 ? 48.0 : size;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: details.onPressed != null,
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: Material(
              color: color,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: details.onPressed,
                onLongPress: details.onLongPress,
                child: SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: details.busy
                        ? SizedBox.square(
                            dimension: size * 0.42,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.sendButtonForegroundColor,
                            ),
                          )
                        : IconTheme.merge(
                            data: IconThemeData(
                              color: theme.sendButtonForegroundColor,
                              size: theme.iconSize,
                            ),
                            child: icon,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the send or done button for the current mode, honouring
/// `ChatImageEditorBuilders.sendButton` / `doneButton`, the external
/// `sendEnabled` switch and the export progress.
class SendButtonSlot extends StatelessWidget {
  /// Creates the slot.
  const SendButtonSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final host = EditorHost.of(context);
    final sendEnabled = host.sendEnabled;
    if (sendEnabled == null) return const _SendButton(enabled: true);
    return ValueListenableBuilder<bool>(
      valueListenable: sendEnabled,
      builder: (context, enabled, _) => _SendButton(enabled: enabled),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final done = scope.config.mode == ChatImageEditorMode.done;

    return ControllerSelector<bool>(
      selector: (c) => c.isExporting,
      builder: (context, busy, _) {
        final active = enabled && !busy;
        final longPress = host.sendLongPress;
        final details = SendButtonDetails(
          enabled: enabled,
          busy: busy,
          onPressed: active ? () => host.send(context) : null,
          onLongPress: active && !done && longPress != null
              ? () => longPress(context)
              : null,
        );
        final builder = done
            ? scope.builders.doneButton
            : scope.builders.sendButton;
        if (builder != null) return builder(context, details);
        return EditorSendButton(
          details: details,
          icon: done ? scope.icons.doneIcon : scope.icons.sendIcon,
          tooltip: done ? scope.strings.done : scope.strings.send,
        );
      },
    );
  }
}
