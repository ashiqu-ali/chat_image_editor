import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import 'chat_message.dart';
import 'export_text.dart';
import 'photo_hero.dart';

/// A chat bubble, at the end of the row for the user's messages and at the
/// start for the contact's. Photo messages show the photo above the caption,
/// with its size and export time in the footer.
class MessageBubble extends StatelessWidget {
  /// Creates a bubble for [message].
  const MessageBubble({super.key, required this.message, this.onOpenPhoto});

  /// The message to show.
  final ChatMessage message;

  /// Called when the photo is tapped.
  final VoidCallback? onOpenPhoto;

  static const Radius _corner = Radius.circular(18);
  static const Radius _tail = Radius.circular(4);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromMe = message.fromMe;
    final photo = message.image;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth * 0.8, 420.0);
        final Widget content;
        if (photo == null) {
          content = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            // Only as wide as the longer of the text and the footer.
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(message.text),
                  ),
                  _Footer(message: message),
                ],
              ),
            ),
          );
        } else {
          final width = math.min(maxWidth, 300.0);
          content = SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Photo(
                    tag: message.id,
                    photo: photo,
                    width: width - 8,
                    onTap: onOpenPhoto,
                  ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: Text(message.text),
                    ),
                  _Footer(message: message),
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: fromMe
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Material(
            color: fromMe
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: fromMe ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.only(
                topStart: _corner,
                topEnd: _corner,
                bottomStart: fromMe ? _corner : _tail,
                bottomEnd: fromMe ? _tail : _corner,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        );
      },
    );
  }
}

/// The photo inside a bubble, decoded at the size it's shown.
class _Photo extends StatelessWidget {
  const _Photo({
    required this.tag,
    required this.photo,
    required this.width,
    required this.onTap,
  });

  final Object tag;
  final ChatImageEditorResult photo;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The result carries its pixel size, so the bubble has its final height
    // before the photo decodes and the list never jumps.
    final aspectRatio = (photo.width / photo.height).clamp(0.7, 1.8);
    final height = width / aspectRatio;

    // Decode only as many pixels as BoxFit.cover shows, instead of the full
    // photo: a 1600 px photo in a 300 pt bubble on a 3x screen decodes at
    // 900 px, about a third of the memory.
    final coverScale = math.max(width / photo.width, height / photo.height);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = math.min(
      photo.width,
      (photo.width * coverScale * pixelRatio).ceil(),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: 'Photo',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: width,
            height: height,
            child: PhotoHero(
              tag: tag,
              child: Image.memory(
                photo.bytes,
                cacheWidth: decodeWidth,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Time, and for photos the file size and export time.
class _Footer extends StatelessWidget {
  const _Footer({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(
      context,
    ).style.color?.withValues(alpha: 0.7);
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: color);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.sentAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final photo = message.image;
    final stats = photo?.stats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 8, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (photo != null)
            Flexible(
              child: Text(
                <String>[
                  formatBytes(photo.bytes.lengthInBytes),
                  if (stats != null) formatDuration(stats.totalTime),
                ].join(' · '),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (photo != null) const SizedBox(width: 8),
          Text(time, style: style),
          if (message.fromMe) ...<Widget>[
            const SizedBox(width: 4),
            Icon(Icons.done_all, size: 16, color: color),
          ],
        ],
      ),
    );
  }
}
