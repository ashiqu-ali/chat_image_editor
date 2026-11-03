import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import '../sample_image.dart';

/// An image the user picked from the gallery or camera.
@immutable
class PickedImage {
  /// Creates a picked image.
  const PickedImage({required this.name, required this.bytes});

  /// File name reported by the picker.
  final String name;

  /// Encoded bytes.
  final Uint8List bytes;
}

/// Previews the image the demos will open and offers ways to change it.
class ImageSourceCard extends StatelessWidget {
  /// Creates the card.
  const ImageSourceCard({
    super.key,
    required this.picked,
    required this.cameraAvailable,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onUseSample,
  });

  /// The picked image, or `null` to use the generated sample.
  final PickedImage? picked;

  /// Whether this platform can take a photo.
  final bool cameraAvailable;

  /// Opens the gallery picker.
  final VoidCallback? onPickFromGallery;

  /// Opens the camera.
  final VoidCallback? onPickFromCamera;

  /// Switches back to the sample image.
  final VoidCallback? onUseSample;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: picked == null
                ? const FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: sampleImageWidth,
                      height: sampleImageHeight,
                      child: CustomPaint(painter: SampleScenePainter()),
                    ),
                  )
                : Image.memory(
                    picked.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 1024,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Center(
                        child: Text(
                          'No preview for this format',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
          ),
          ListTile(
            title: Text(picked == null ? 'Sample image' : picked.name),
            subtitle: Text(
              picked == null
                  ? 'Drawn with dart:ui at '
                        '${sampleImageWidth.round()} × '
                        '${sampleImageHeight.round()}. '
                        'Nothing to download or set up.'
                  : ChatImageEditorStrings.defaultFormatBytes(
                      picked.bytes.lengthInBytes,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onPickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                if (cameraAvailable)
                  FilledButton.tonalIcon(
                    onPressed: onPickFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                if (picked != null)
                  TextButton.icon(
                    onPressed: onUseSample,
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('Use sample'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
