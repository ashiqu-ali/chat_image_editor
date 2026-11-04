import 'package:flutter/material.dart';

import '../theme/chat_image_editor_scope.dart';

/// A rounded, translucent text button, such as the "Done" that ends drawing
/// or text entry.
///
/// Sits on the same backdrop as `EditorIconButton`, so it reads on any photo.
class EditorPillButton extends StatelessWidget {
  /// Creates a pill button.
  const EditorPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// The button text, also its tooltip and semantics label.
  final String label;

  /// Tap handler.
  final VoidCallback onPressed;

  /// Height of the hit target, the same as an icon button's.
  static const double hitHeight = 48;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: SizedBox(
            height: hitHeight,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.toolbarBackgroundColor,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  child: Text(
                    label,
                    style: theme.labelStyle.copyWith(
                      color: theme.foregroundColor,
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
