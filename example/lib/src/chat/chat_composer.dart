import 'package:flutter/material.dart';

/// Where a photo comes from.
enum PhotoSource {
  /// The photo library.
  gallery,

  /// The camera.
  camera,

  /// The sample landscape, drawn in the app.
  sample,
}

/// Asks where the photo should come from. Completes with `null` if the
/// sheet is dismissed.
Future<PhotoSource?> showPhotoSourceSheet(
  BuildContext context, {
  required bool cameraAvailable,
}) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      void choose(PhotoSource source) => Navigator.of(context).pop(source);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => choose(PhotoSource.gallery),
            ),
            if (cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => choose(PhotoSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.landscape_outlined),
              title: const Text('Sample photo'),
              subtitle: const Text('Drawn by the app, no permission needed'),
              onTap: () => choose(PhotoSource.sample),
            ),
          ],
        ),
      );
    },
  );
}

/// The message field with attach and send buttons.
///
/// The round button sends the typed message, or attaches a photo while the
/// field is empty.
class ChatComposer extends StatelessWidget {
  /// Creates the composer.
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.busy = false,
  });

  /// The draft message.
  final TextEditingController controller;

  /// Sends the draft.
  final VoidCallback onSend;

  /// Starts attaching a photo, or `null` to disable it.
  final VoidCallback? onAttach;

  /// Shows a progress bar while a photo is being prepared.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        12,
                        8,
                        12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Attach a photo',
                        icon: const Icon(Icons.attach_file),
                        onPressed: onAttach,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return IconButton.filled(
                      tooltip: hasText ? 'Send' : 'Send a photo',
                      iconSize: 24,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                      ),
                      onPressed: hasText ? onSend : onAttach,
                      icon: Icon(
                        hasText ? Icons.send : Icons.add_photo_alternate,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
