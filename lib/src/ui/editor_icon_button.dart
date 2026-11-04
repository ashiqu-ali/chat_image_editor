import 'package:flutter/material.dart';

import '../theme/chat_image_editor_scope.dart';

/// A circular, translucent icon button used across the editor's toolbars.
///
/// The hit target is 48×48 with a smaller dark circular backdrop that keeps
/// the icon readable on light and dark photos alike. The selected tool or
/// option is drawn in the accent color. Colors come from the resolved theme;
/// the icon inherits them through `IconTheme`, so user-supplied `Icon`s
/// without an explicit color match the editor.
class EditorIconButton extends StatelessWidget {
  /// Creates a toolbar button.
  const EditorIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.backdrop = true,
  });

  /// The icon widget.
  final Widget icon;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Draws the icon in the accent color, for the selected tool or option.
  final bool active;

  /// Draws the circular backdrop. Turn off for buttons on solid surfaces.
  final bool backdrop;

  /// Diameter of the hit target.
  static const double hitSize = 48;

  /// Diameter of the circular backdrop.
  static const double backdropSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    final enabled = onPressed != null;
    final background = backdrop ? theme.toolbarBackgroundColor : null;
    final foreground = active ? theme.activeToolColor : theme.foregroundColor;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: active,
        child: InkResponse(
          onTap: onPressed,
          radius: hitSize / 2,
          child: SizedBox.square(
            dimension: hitSize,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: backdropSize,
                height: backdropSize,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: foreground,
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
    );
  }
}
