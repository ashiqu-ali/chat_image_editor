import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import 'edit_summary.dart';

/// Shows what the editor returned: the image, caption, dimensions, format
/// and file size.
class ResultScreen extends StatelessWidget {
  /// Creates the screen for [result].
  const ResultScreen({
    super.key,
    required this.result,
    required this.title,
    this.maxBytes,
  });

  /// The editor's result.
  final ChatImageEditorResult result;

  /// Name of the demo that produced [result].
  final String title;

  /// The size limit the demo asked for, if any.
  final int? maxBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const formatBytes = ChatImageEditorStrings.defaultFormatBytes;
    final size = result.bytes.lengthInBytes;
    final limit = maxBytes;

    return Scaffold(
      appBar: AppBar(title: Text('$title result')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = math.max(16.0, (constraints.maxWidth - 720) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
            children: <Widget>[
              Card(
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: Center(
                    heightFactor: 1,
                    child: AspectRatio(
                      aspectRatio: result.width / result.height,
                      // The checkerboard shows through transparent PNGs.
                      child: CustomPaint(
                        painter: _CheckerboardPainter(
                          light: scheme.surfaceContainerLow,
                          dark: scheme.surfaceContainerHighest,
                        ),
                        child: Image.memory(
                          result.bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (result.exceedsMaxBytes)
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    iconColor: scheme.onErrorContainer,
                    textColor: scheme.onErrorContainer,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text('Over the size limit'),
                    subtitle: const Text(
                      'Even the lowest allowed quality did not fit, so this '
                      'is the smallest attempt.',
                    ),
                  ),
                ),
              Card(
                child: Column(
                  children: <Widget>[
                    _InfoTile(
                      icon: Icons.short_text,
                      label: 'Caption',
                      value: result.caption.isEmpty
                          ? 'No caption'
                          : result.caption,
                    ),
                    _InfoTile(
                      icon: Icons.aspect_ratio,
                      label: 'Dimensions',
                      value: '${result.width} × ${result.height} px',
                    ),
                    _InfoTile(
                      icon: Icons.image_outlined,
                      label: 'Format',
                      value:
                          '${result.format.name.toUpperCase()} · '
                          '${result.mimeType} · .${result.fileExtension}',
                    ),
                    _InfoTile(
                      icon: Icons.sd_storage_outlined,
                      label: 'Size',
                      value: limit == null
                          ? '${formatBytes(size)} ($size bytes)'
                          : '${formatBytes(size)} of '
                                '${formatBytes(limit)} allowed',
                    ),
                    _InfoTile(
                      icon: Icons.layers_outlined,
                      label: 'Edits',
                      value: describeEdits(result.edits),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({required this.light, required this.dark});

  static const double _cell = 12;

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var row = 0; row * _cell < size.height; row++) {
      for (
        var column = row.isOdd ? 1 : 0;
        column * _cell < size.width;
        column += 2
      ) {
        canvas.drawRect(
          Rect.fromLTWH(column * _cell, row * _cell, _cell, _cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) {
    return light != oldDelegate.light || dark != oldDelegate.dark;
  }
}
