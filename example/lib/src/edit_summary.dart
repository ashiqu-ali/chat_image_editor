import 'package:chat_image_editor/chat_image_editor.dart';

/// A one-line, human-readable summary of [value], such as
/// `2 strokes · 1 text layer · rotated 90°`.
String describeEdits(ImageEditValue value) {
  final parts = <String>[
    if (value.strokes.isNotEmpty) _plural(value.strokes.length, 'stroke'),
    if (value.texts.isNotEmpty) _plural(value.texts.length, 'text layer'),
    if (value.crop != null) 'cropped',
    if (value.quarterTurns != 0) 'rotated ${value.quarterTurns * 90}°',
    if (value.flipX || value.flipY) 'mirrored',
    if (value.quality != null) 'quality ${value.quality}',
  ];
  return parts.isEmpty ? 'No edits' : parts.join(' · ');
}

String _plural(int count, String noun) {
  return count == 1 ? '1 $noun' : '$count ${noun}s';
}
