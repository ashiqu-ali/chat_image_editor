import 'package:flutter/painting.dart';

import '../../models/editor_enums.dart';
import '../../models/text_layer.dart';

/// The colors a text layer is painted with, for each background style.
///
/// The one place this rule lives: the renderer (preview and export) and the
/// text entry overlay both read it, so typing looks like the result.
/// Internal: not exported from the package.
abstract final class TextLayerColors {
  /// Box color for [TextBackgroundStyle.translucent]: black at 50%.
  static const Color translucentBox = Color(0x80000000);

  /// Text on a light solid box.
  static const Color _black = Color(0xFF000000);

  /// Text on a dark solid box.
  static const Color _white = Color(0xFFFFFFFF);

  /// Color of the glyphs: black or white by luminance on a solid box (which
  /// takes the layer color), otherwise the layer color.
  static Color textColor(TextLayer layer) {
    if (layer.background == TextBackgroundStyle.solid) {
      return layer.color.computeLuminance() > 0.5 ? _black : _white;
    }
    return layer.color;
  }

  /// Color of the rounded box behind the text, or `null` for none.
  static Color? boxColor(TextLayer layer) {
    switch (layer.background) {
      case TextBackgroundStyle.none:
        return null;
      case TextBackgroundStyle.solid:
        return layer.color;
      case TextBackgroundStyle.translucent:
        return translucentBox;
    }
  }
}
