import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/chat_image_editor_scope.dart';
import 'editor_haptics.dart';

/// A vertical strip of swatches from `theme.palette`.
///
/// Tap a swatch, or drag along the strip to sweep through the colors. The
/// strip shrinks its swatches to fit the height it's given. Screen readers
/// see one labelled, selectable button per swatch.
class ColorStrip extends StatelessWidget {
  /// Creates a color strip.
  const ColorStrip({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The current color; its swatch is enlarged.
  final Color selected;

  /// Called with the picked color.
  final ValueChanged<Color> onSelected;

  /// Width of the strip (and of its touch area).
  static const double width = 48;

  /// Largest height of one swatch row.
  static const double maxExtent = 32;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final palette = scope.theme.palette;
    if (palette.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight / palette.length
            : maxExtent;
        final extent = math.max(12.0, math.min(maxExtent, available));

        void select(Color color) {
          if (color != selected) {
            editorHaptic(enabled: scope.config.enableHaptics);
            onSelected(color);
          }
        }

        void pick(Offset local) {
          final index = (local.dy / extent).floor().clamp(
            0,
            palette.length - 1,
          );
          select(palette[index]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Each swatch exposes its own tap action instead of the strip's
          // position-based gestures.
          excludeFromSemantics: true,
          onTapDown: (details) => pick(details.localPosition),
          onVerticalDragStart: (details) => pick(details.localPosition),
          onVerticalDragUpdate: (details) => pick(details.localPosition),
          child: SizedBox(
            width: width,
            height: extent * palette.length,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < palette.length; i++)
                  SizedBox(
                    height: extent,
                    child: Center(
                      child: _Swatch(
                        color: palette[i],
                        selected: palette[i] == selected,
                        diameter: extent * 0.7,
                        label: scope.strings.colorLabel(
                          palette[i],
                          i,
                          palette.length,
                        ),
                        onTap: () => select(palette[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.diameter,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double diameter;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    final size = selected ? diameter * 1.3 : diameter;
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.foregroundColor,
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}
