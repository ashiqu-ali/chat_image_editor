import 'package:chat_image_editor/chat_image_editor.dart';

/// Formats a byte count the way the editor does, such as `61.7 KB`.
String formatBytes(int bytes) =>
    ChatImageEditorStrings.defaultFormatBytes(bytes);

/// Formats an export phase's duration, such as `182 ms` or `1.4 s`.
String formatDuration(Duration duration) {
  final milliseconds = duration.inMicroseconds / 1000;
  if (milliseconds < 1000) return '${milliseconds.round()} ms';
  return '${(milliseconds / 1000).toStringAsFixed(1)} s';
}

/// How the sent photo's size compares with the photo the user picked, such
/// as `46% smaller`.
String describeSizeChange(int sourceBytes, int outputBytes) {
  if (sourceBytes <= 0) return '';
  final change = (outputBytes - sourceBytes) / sourceBytes * 100;
  final percent = change.abs().round();
  if (percent == 0) return 'same size';
  return change < 0 ? '$percent% smaller' : '$percent% larger';
}
