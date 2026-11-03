import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/render/text_layer_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

TextLayer _layer(Color color, TextBackgroundStyle background) {
  return TextLayer(
    id: 't',
    text: 'A',
    position: const Offset(0.5, 0.5),
    fontSize: 0.1,
    color: color,
    background: background,
  );
}

void main() {
  const yellow = Color(0xFFFFEB3B);
  const navy = Color(0xFF1A237E);

  test('no background: text in the layer color, no box', () {
    final layer = _layer(navy, TextBackgroundStyle.none);
    expect(TextLayerColors.textColor(layer), navy);
    expect(TextLayerColors.boxColor(layer), isNull);
  });

  test('solid: box in the layer color, text contrasts by luminance', () {
    final light = _layer(yellow, TextBackgroundStyle.solid);
    expect(TextLayerColors.boxColor(light), yellow);
    expect(TextLayerColors.textColor(light), const Color(0xFF000000));

    final dark = _layer(navy, TextBackgroundStyle.solid);
    expect(TextLayerColors.boxColor(dark), navy);
    expect(TextLayerColors.textColor(dark), const Color(0xFFFFFFFF));
  });

  test('translucent: half-transparent black box, text in the layer color', () {
    final layer = _layer(yellow, TextBackgroundStyle.translucent);
    expect(TextLayerColors.textColor(layer), yellow);
    expect(TextLayerColors.boxColor(layer), TextLayerColors.translucentBox);
    expect(TextLayerColors.translucentBox, const Color(0x80000000));
  });
}
