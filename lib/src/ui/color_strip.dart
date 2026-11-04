import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/chat_image_editor_scope.dart';
import 'editor_haptics.dart';

/// A vertical gradient color slider through `theme.palette`.
///
/// Tap or drag along the strip to pick any color between the palette's
/// stops; the thumb shows the current color. Screen readers get a slider
/// that steps through the palette colors.
class ColorStrip extends StatefulWidget {
  /// Creates a color strip.
  const ColorStrip({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The current color, shown in the thumb.
  final Color selected;

  /// Called with the picked color, continuously while dragging.
  final ValueChanged<Color> onSelected;

  /// Width of the strip's touch area.
  static const double width = 48;

  /// Width of the gradient bar.
  static const double barWidth = 12;

  /// Diameter of the thumb.
  static const double thumbSize = 26;

  /// Tallest the strip grows. It shrinks to the height it's given.
  static const double maxHeight = 300;

  /// The color at [t] along a gradient through [palette], from the first
  /// color at `0` to the last at `1`. The palette's own colors are returned
  /// exactly at their stops.
  static Color colorAt(List<Color> palette, double t) {
    if (palette.length == 1) return palette.first;
    final position = t.clamp(0.0, 1.0) * (palette.length - 1);
    final index = math.min(position.floor(), palette.length - 2);
    final local = position - index;
    if (local <= 0) return palette[index];
    if (local >= 1) return palette[index + 1];
    return Color.lerp(palette[index], palette[index + 1], local)!;
  }

  /// Where along a gradient through [palette] the color closest to [color]
  /// sits, from `0` to `1`.
  static double positionOf(List<Color> palette, Color color) {
    if (palette.length < 2) return 0;
    for (var i = 0; i < palette.length; i++) {
      if (palette[i] == color) return i / (palette.length - 1);
    }
    const samples = 240;
    var best = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final candidate = colorAt(palette, t);
      final dr = candidate.r - color.r;
      final dg = candidate.g - color.g;
      final db = candidate.b - color.b;
      final distance = dr * dr + dg * dg + db * db;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = t;
      }
    }
    return best;
  }

  @override
  State<ColorStrip> createState() => _ColorStripState();
}

class _ColorStripState extends State<ColorStrip> {
  /// The last position this strip picked, and the color it picked there.
  /// While the selection is still that color the thumb stays exactly where
  /// the finger left it, without searching the gradient.
  double? _pickedAt;
  Color? _picked;

  double _position(List<Color> palette) {
    final pickedAt = _pickedAt;
    if (pickedAt != null && _picked == widget.selected) return pickedAt;
    return ColorStrip.positionOf(palette, widget.selected);
  }

  void _pick(double t, List<Color> palette) {
    final color = ColorStrip.colorAt(palette, t);
    setState(() {
      _pickedAt = t;
      _picked = color;
    });
    if (color != widget.selected) widget.onSelected(color);
  }

  void _step(int index, List<Color> palette) {
    final clamped = index.clamp(0, palette.length - 1);
    _pick(clamped / math.max(1, palette.length - 1), palette);
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final strings = scope.strings;
    final palette = theme.palette;
    if (palette.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : ColorStrip.maxHeight;
        final height = math.min(available, ColorStrip.maxHeight);
        const thumb = ColorStrip.thumbSize;
        if (height < thumb * 2) return const SizedBox.shrink();
        final track = height - thumb;
        final position = _position(palette);
        final nearest = (position * (palette.length - 1)).round();

        double toT(Offset local) =>
            ((local.dy - thumb / 2) / track).clamp(0.0, 1.0);

        String describe(int index) {
          final i = index.clamp(0, palette.length - 1);
          return strings.colorLabel(palette[i], i, palette.length);
        }

        return Semantics(
          container: true,
          slider: true,
          label: strings.color,
          value: describe(nearest),
          increasedValue: nearest < palette.length - 1
              ? describe(nearest + 1)
              : null,
          decreasedValue: nearest > 0 ? describe(nearest - 1) : null,
          onIncrease: nearest < palette.length - 1
              ? () => _step(nearest + 1, palette)
              : null,
          onDecrease: nearest > 0 ? () => _step(nearest - 1, palette) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (details) {
              editorHaptic(enabled: scope.config.enableHaptics);
              _pick(toT(details.localPosition), palette);
            },
            onVerticalDragStart: (details) =>
                _pick(toT(details.localPosition), palette),
            onVerticalDragUpdate: (details) =>
                _pick(toT(details.localPosition), palette),
            child: SizedBox(
              width: ColorStrip.width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    top: thumb / 2,
                    bottom: thumb / 2,
                    left: (ColorStrip.width - ColorStrip.barWidth) / 2,
                    width: ColorStrip.barWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(ColorStrip.barWidth / 2),
                        ),
                        border: Border.all(
                          color: theme.foregroundColor.withValues(alpha: 0.6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: palette.length == 1
                              ? <Color>[palette.first, palette.first]
                              : palette,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: position * track,
                    left: (ColorStrip.width - thumb) / 2,
                    width: thumb,
                    height: thumb,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.selected,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.foregroundColor,
                          width: 2.5,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Color(0x66000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
