import 'package:flutter/material.dart';

import '../theme/chat_image_editor_scope.dart';

/// A slider colored from the editor's resolved theme.
class EditorSlider extends StatelessWidget {
  /// Creates a themed slider.
  const EditorSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticsLabel,
    this.onChangeEnd,
    this.divisions,
    this.semanticFormatterCallback,
  });

  /// Current value, clamped into [min]..[max] before display.
  final double value;

  /// Smallest value.
  final double min;

  /// Largest value.
  final double max;

  /// Called while the thumb moves.
  final ValueChanged<double> onChanged;

  /// Called when the user lets go.
  final ValueChanged<double>? onChangeEnd;

  /// Number of discrete steps, or `null` for continuous.
  final int? divisions;

  /// Label announced by screen readers.
  final String semanticsLabel;

  /// Formats the value for screen readers.
  final SemanticFormatterCallback? semanticFormatterCallback;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    // One node: screen readers announce the label with the slider's value
    // and actions, instead of stopping on the label first.
    return MergeSemantics(
      child: Semantics(
        label: semanticsLabel,
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          activeColor: theme.sliderActiveColor,
          inactiveColor: theme.sliderInactiveColor,
          thumbColor: theme.sliderThumbColor,
          overlayColor: WidgetStatePropertyAll<Color>(
            theme.sliderActiveColor.withValues(alpha: 0.16),
          ),
          semanticFormatterCallback: semanticFormatterCallback,
        ),
      ),
    );
  }
}
