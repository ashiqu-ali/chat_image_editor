# chat_image_editor

A lightweight, WhatsApp-style image editor for chat apps: draw, add text,
crop, rotate, compress and send with a caption. Pure Dart and fully
themeable.

[![pub package](https://img.shields.io/pub/v/chat_image_editor.svg)](https://pub.dev/packages/chat_image_editor)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)


| Draw | Text | Crop | Compress | Done mode |
|---|---|---|---|---|
| ![Draw tool](doc/screenshots/draw.png) | ![Text tool](doc/screenshots/text.png) | ![Crop tool](doc/screenshots/crop.png) | ![Compress sheet](doc/screenshots/compress.png) | ![Done mode](doc/screenshots/done_mode.png) |

## Features

- **Draw**: freehand pen, line, rectangle, circle and arrow, with a brush
  size slider and a color strip you drag along to pick a color.
- **Text**: add, edit, move, pinch to resize and twist to rotate. Center
  snap guides, solid or translucent backgrounds and drag-to-delete.
- **Crop, rotate and flip**: draggable corners and edges, a rule-of-thirds
  grid, aspect-ratio presets, quarter turns and mirroring.
- **Compress**: a quality slider with the original size and a live estimate
  of the new size. Optionally cap the output with `maxBytes`.
- **Undo and redo** for every edit.
- **Caption and send**: a real `TextFormField` you configure (validator,
  max length, formatters, your own controller) and a send button with
  optional long-press and enable/disable control.
- **Done mode**: no caption, one done button. Good for avatars and
  attachments outside a chat.
- **Matches your app**: accent colors come from your `ColorScheme`. Override
  any color, icon, string or whole UI region.
- **Sharp, small output**: edits are stored as data and rendered once at
  export, at full resolution, capped by `maxLongEdge`. JPEG or PNG.
- **Pure Dart**: no platform plugins, so it runs everywhere Flutter does.

## Install

```bash
flutter pub add chat_image_editor
```

Or add it to `pubspec.yaml` yourself:

```yaml
dependencies:
  chat_image_editor: ^0.1.0
```

Requires Dart 3.8 and Flutter 3.32 or newer.

## Quick start

Open the editor with the image bytes and await the result. It's `null` when
the user closes the editor without sending.

```dart
import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

Future<void> editAndSend(BuildContext context, Uint8List photo) async {
  final result = await ChatImageEditor.open(context, photo);
  if (result == null) return; // The user closed the editor.

  // Your upload code: the bytes, the caption and the file type.
  await uploadImage(
    result.bytes,
    caption: result.caption,
    mimeType: result.mimeType,
  );
}
```

`photo` is any encoded image Flutter can decode (JPEG, PNG, WebP, …). Get it
from wherever you like, for example `XFile.readAsBytes()` from
`image_picker`, a file or the network.

The `ChatImageEditorResult` gives you:

| Member | What it is |
|---|---|
| `bytes` | The encoded image. |
| `width`, `height` | Pixel size of the encoded image. |
| `format`, `mimeType`, `fileExtension` | `ExportFormat.jpeg` or `.png`, e.g. `image/jpeg` and `jpg`. |
| `caption` | The caption, trimmed. Empty in done mode. |
| `edits` | The `ImageEditValue` that produced the image. |
| `exceedsMaxBytes` | `true` if a `maxBytes` target couldn't be met. |

## Done mode

Done mode swaps the caption and send button for a single done button. Use it
when you only need the edited image, such as a profile photo.

```dart
final result = await ChatImageEditor.open(
  context,
  photo,
  config: const ChatImageEditorConfig(mode: ChatImageEditorMode.done),
);
```

## Embed the widget

`ChatImageEditor.open` pushes a full-screen route for you. To place the
editor in your own route or layout, use the widget and handle `onComplete`
and `onCancel`:

```dart
class EditPhotoPage extends StatelessWidget {
  const EditPhotoPage({super.key, required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    return ChatImageEditor(
      image: photo,
      onComplete: (result) {
        // Send result.bytes and result.caption, then leave the page.
        Navigator.of(context).pop(result);
      },
      onCancel: () => Navigator.of(context).pop(),
    );
  }
}
```

If you leave `onComplete` or `onCancel` out, the editor pops its route with
the result or with `null`.

## Customize it

Everything below is optional. The full reference, with every field and its
default, is in [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md).

### Theme

Out of the box the editor uses a dark, full-bleed canvas and takes its accent
(send button, sliders, active tool, guides, first draw color) from your
app's `ColorScheme.primary`. Change your seed color and the editor follows.

Override any single field with `ChatImageEditorThemeData`. Fields you leave
`null` keep inheriting.

```dart
ChatImageEditor.open(
  context,
  photo,
  theme: const ChatImageEditorThemeData(
    sendButtonColor: Colors.teal,
    captionFillColor: Color(0xFF1F2C34),
    palette: [Colors.white, Colors.black, Colors.red, Colors.amber],
  ),
);
```

To style every editor in your app at once, register the theme as a
`ThemeExtension`:

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    extensions: const [
      ChatImageEditorThemeData(backgroundColor: Color(0xFF101010)),
    ],
  ),
  home: const HomePage(),
);
```

Each field resolves in this order: the `theme` you pass to the editor, then
the extension, then the default from your `ColorScheme`.

### Icons

Pass any widget: an `Icon`, an SVG or an image. Icons without their own color
pick up the themed color.

```dart
ChatImageEditor.open(
  context,
  photo,
  icons: const ChatImageEditorIcons(
    send: Icon(Icons.arrow_upward),
    draw: Icon(Icons.brush),
  ),
);
```

### Strings and localization

Every user-facing string, tooltip and semantics label lives in
`ChatImageEditorStrings`, with English defaults. Pass a translated instance:

```dart
ChatImageEditor.open(
  context,
  photo,
  strings: const ChatImageEditorStrings(
    captionHint: 'Ajouter une légende…',
    send: 'Envoyer',
    discardTitle: 'Annuler les modifications ?',
    discardConfirm: 'Annuler',
    keepEditing: 'Continuer',
  ),
);
```

Pick the instance from `Localizations.localeOf(context)` or fill it from your
app's generated localizations.

### Caption field

The caption is a real `TextFormField`. Configure it with
`CaptionFieldConfig`:

```dart
ChatImageEditor.open(
  context,
  photo,
  captionField: CaptionFieldConfig(
    maxLength: 500,
    maxLines: 4,
    validator: (value) =>
        (value ?? '').contains('http') ? 'Links are not allowed' : null,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    header: const Text('Sending to Family'),
  ),
);
```

Sending is blocked while the validator returns an error. Set `enabled: false`
to hide the caption and keep only the send button.

### Send button behaviour

- `sendEnabled` takes a `ValueListenable<bool>`. The send button is disabled
  while it's `false`, for example while you're offline.
- `onSendLongPress` runs on a long press of the send button. It receives an
  `export` function so you can render the image on demand, for example after
  the user picks a time to schedule the message. Return `true` to close the
  editor or `false` to stay.

```dart
final online = ValueNotifier<bool>(true);

ChatImageEditor.open(
  context,
  photo,
  sendEnabled: online,
  onSendLongPress: (context, export) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return false;
    final result = await export();
    if (result == null) return false;
    scheduleImage(result, time); // Your code.
    return true;
  },
);
```

### Builders

Replace whole parts of the UI with `ChatImageEditorBuilders`: the top bar,
the bottom bar, the send or done button, the loading and error views, and the
discard confirmation.

```dart
ChatImageEditor.open(
  context,
  photo,
  builders: ChatImageEditorBuilders(
    sendButton: (context, details) => FilledButton.icon(
      onPressed: details.onPressed,
      onLongPress: details.onLongPress,
      icon: const Icon(Icons.send),
      label: Text(details.busy ? 'Sending…' : 'Send'),
    ),
  ),
);
```

Inside a builder, `ChatImageEditorScope.of(context)` gives you the resolved
theme, icons, strings, config and controller, so custom widgets can match the
editor.

### Behaviour

`ChatImageEditorConfig` switches features on and off: which tools appear and
in what order, the draw shapes, crop presets, brush and text size limits,
pinch-to-zoom, haptics, undo/redo buttons and the discard prompt.

```dart
const config = ChatImageEditorConfig(
  tools: [EditorTool.draw, EditorTool.text, EditorTool.crop],
  shapes: [ShapeType.freehand, ShapeType.arrow],
  cropAspectRatios: [1],
  enableHaptics: false,
);
```

### Controller

Pass your own `ChatImageEditorController` to drive the editor from code or to
read its state. It's a `ChangeNotifier`, so you can listen to it.

```dart
final controller = ChatImageEditorController();

ChatImageEditor(image: photo, controller: controller);

// Later, from your own buttons:
controller.selectTool(EditorTool.draw);
controller.setDrawColor(Colors.yellow);
if (controller.canUndo) controller.undo();

// Rotate in a crop session and keep it as one undo step.
controller.selectTool(EditorTool.crop);
controller.rotateRight();
controller.confirmCrop();

final result = await controller.export(caption: 'Hello');
```

The editor disposes the controller it creates itself. A controller you pass
in is yours to dispose.

## Export options

`ChatImageEditorConfig.export` controls how the result is encoded.

```dart
const config = ChatImageEditorConfig(
  export: ExportOptions(
    format: ExportFormat.jpeg, // or ExportFormat.png
    quality: 85, // used unless the user picks one in the compress tool
    maxLongEdge: 1600, // scale down large photos; null keeps full size
    maxBytes: 300 * 1024, // lower JPEG quality until the file fits
    minQuality: 40, // never go below this while fitting maxBytes
  ),
);
```

| Option | Default | What it does |
|---|---|---|
| `format` | `ExportFormat.jpeg` | JPEG (small, no transparency) or PNG (lossless, keeps transparency). |
| `quality` | `90` | JPEG quality, 1–100, unless the user picks one in the compress tool. |
| `maxLongEdge` | `4096` | Longest side of the output in pixels. `null` keeps the full resolution. |
| `maxBytes` | `null` | Target file size. JPEG quality steps down until the file fits. |
| `minQuality` | `30` | Lowest quality the `maxBytes` search may use. |
| `encoder` | `null` | Your own `ImageEncoder`. `null` uses the built-in `DartImageEncoder`. |
| `backgroundColor` | white | Fills transparent pixels for JPEG output. |

If the file still doesn't fit at `minQuality`, you get the smallest attempt
and `result.exceedsMaxBytes` is `true`. Quality applies to JPEG only; if you
export PNG you may want to leave `EditorTool.compress` out of
`config.tools`.

### Custom encoder

The built-in encoder is pure Dart, so it works everywhere. To use a faster
native encoder, implement `ImageEncoder`. You get straight (not
premultiplied) RGBA pixels:

```dart
class MyEncoder implements ImageEncoder {
  const MyEncoder();

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) async {
    // image.pixels holds width * height * 4 bytes, row by row.
    return encodeWithMyLibrary(
      image.pixels,
      image.width,
      image.height,
      format.mimeType,
      quality,
    );
  }
}

const config = ChatImageEditorConfig(
  export: ExportOptions(encoder: MyEncoder()),
);
```

## Performance

Every export reports how long it took in `result.stats` (an `ExportStats`:
decode, render and encode times, encode attempts, final quality and byte
sizes), so you can track export performance in your own analytics. The
package itself never sends anything anywhere.

```dart
final result = await ChatImageEditor.open(context, photo);
final stats = result?.stats;
if (stats != null) {
  debugPrint('Export took ${stats.totalTime.inMilliseconds} ms '
      'in ${stats.encodeAttempts} encode(s)');
}
```

The expensive steps also show up as `chat_image_editor.*` spans in the
Performance view of Flutter DevTools. See
[docs/PERFORMANCE.md](docs/PERFORMANCE.md) for the span names, the
benchmark suite, the frame-timing tests and tuning tips.

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

The package is pure Dart: everything is painted with `CustomPaint` and
encoded with [`image`](https://pub.dev/packages/image). There's no native
code and no platform setup. Encoding runs in a background isolate where
isolates are available; on the web it runs on the main thread.

## Static images only

The editor works with still images. GIFs, video and animated stickers are
out of scope.

## Example app

The [example](example) app shows every customization option: the default
look, a custom theme, done mode, a size limit, localized strings and an
external controller. See [example/README.md](example/README.md) to run it.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup
and the checks to run, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for
how the editor is built. Please follow the
[Code of Conduct](CODE_OF_CONDUCT.md) and report security issues as described
in [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).

## Disclaimer

"WhatsApp-style" describes the look and feel only. Not affiliated with,
endorsed by or sponsored by WhatsApp or Meta.
