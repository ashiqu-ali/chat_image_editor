import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import '../edit_summary.dart';
import 'chat_message.dart';
import 'export_text.dart';
import 'photo_hero.dart';

/// Shows a sent photo full screen, zoomable, with how it was exported.
class PhotoViewerScreen extends StatelessWidget {
  /// Creates the viewer for a photo [message].
  const PhotoViewerScreen({
    super.key,
    required this.message,
    required this.senderName,
  });

  /// The photo message. Its `image` must not be `null`.
  final ChatMessage message;

  /// Who sent it, for the app bar.
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final photo = message.image!;
    final appTheme = Theme.of(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.sentAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    // Photo viewers are dark whatever the app's brightness.
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appTheme.colorScheme.primary,
          brightness: Brightness.dark,
        ),
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(senderName),
                  Text(time, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            body: Column(
              children: <Widget>[
                Expanded(
                  child: InteractiveViewer(
                    maxScale: 6,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: photo.width / photo.height,
                        child: PhotoHero(
                          tag: message.id,
                          child: Image.memory(
                            photo.bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (message.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      message.text,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ExportDetails(result: photo),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What the editor produced and how long it took, from
/// `ChatImageEditorResult.stats`.
class ExportDetails extends StatelessWidget {
  /// Creates the details for [result].
  const ExportDetails({super.key, required this.result});

  /// The editor's result.
  final ChatImageEditorResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = result.stats;
    final outputBytes = result.bytes.lengthInBytes;
    final quality = stats?.finalQuality;

    final rows = <Widget>[
      _DetailRow(
        icon: Icons.photo_size_select_large,
        label: 'Sent',
        value: <String>[
          '${result.width} × ${result.height}',
          result.format.name.toUpperCase(),
          if (quality != null) 'quality $quality',
        ].join(' · '),
      ),
      if (stats != null) ...<Widget>[
        _DetailRow(
          icon: Icons.compress,
          label: 'Size',
          value:
              '${formatBytes(stats.sourceByteLength)} picked → '
              '${formatBytes(outputBytes)} sent '
              '(${describeSizeChange(stats.sourceByteLength, outputBytes)})',
        ),
        _DetailRow(
          icon: Icons.timer_outlined,
          label: 'Export',
          value: <String>[
            '${formatDuration(stats.totalTime)} total',
            'decode ${formatDuration(stats.decodeTime)}',
            'render ${formatDuration(stats.renderTime)}',
            'encode ${formatDuration(stats.encodeTime)}',
            if (stats.encodeAttempts > 1) '${stats.encodeAttempts} passes',
          ].join(' · '),
        ),
      ] else
        _DetailRow(
          icon: Icons.compress,
          label: 'Size',
          value: formatBytes(outputBytes),
        ),
      _DetailRow(
        icon: Icons.layers_outlined,
        label: 'Edits',
        value: describeEdits(result.edits),
      ),
    ];

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
