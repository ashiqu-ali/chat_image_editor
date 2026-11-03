import 'package:flutter/widgets.dart';

import '../theme/chat_image_editor_scope.dart';

/// The drag-to-delete target shown while a text layer is moved.
///
/// The canvas hit-tests dragged layers against this widget's box, so give
/// it the editor's delete target key.
class DeleteTarget extends StatelessWidget {
  /// Creates the target.
  const DeleteTarget({super.key, required this.active});

  /// Whether a layer hovers over the target.
  final bool active;

  /// Diameter of the target.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    return Semantics(
      label: scope.strings.delete,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedScale(
          scale: active ? 1.2 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: active
                  ? theme.deleteTargetActiveColor
                  : theme.deleteTargetColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.foregroundColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: IconTheme.merge(
              data: IconThemeData(
                color: theme.foregroundColor,
                size: theme.iconSize,
              ),
              child: scope.icons.deleteIcon,
            ),
          ),
        ),
      ),
    );
  }
}
