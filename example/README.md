# chat_image_editor example

A chat app that sends photos through `chat_image_editor`, the way a
messaging app would use it, plus a screen with every customization option.

```bash
fvm flutter pub get
fvm flutter run
```

It works with zero setup: "Sample photo" draws a landscape with `dart:ui`.
You can also pick a photo from the gallery or take one with the camera (where
the platform supports it).

## The chat

1. Type a message if you like, then tap the paperclip or the photo button.
2. Pick a photo. The editor opens with your message as the caption.
3. Draw, add text, crop, rotate or change the quality, then send.

The photo arrives as a chat bubble with its file size and how long the
export took. Tap it to zoom, and to see the full `ExportStats`: picked size
against sent size, output dimensions and quality, and the decode, render and
encode times.

What the chat does to stay fast:

- **One call to the editor.** `editPhotoForChat` in
  `lib/src/chat/chat_photo_editor.dart` is the whole integration. It caps
  photos at 1600 px, quality 80 and 1 MB. In testing, a 12 MP, 5.8 MB photo
  went out as a 230 KB JPEG.
- **No resize in the picker.** The original goes straight to the editor,
  which decodes it only at the size it needs. Resizing in `image_picker`
  would add a second lossy encode.
- **Thumbnails decoded at bubble size.** Bubbles pass `cacheWidth`, so a
  1600 px photo in a 300 pt bubble decodes at the pixels it shows, not at
  full size.
- **No layout jumps.** The result carries its pixel size, so a bubble has
  its final height before the photo decodes.
- **Stable list items.** Messages are keyed and the list uses
  `findChildIndexCallback`, so a new message doesn't rebuild every bubble's
  image.
- **Logging.** Each export's `ExportStats` goes to DevTools' Logging view;
  send it to your own analytics to watch export times on real devices.

## Customization demos

Open them from the tune button in the chat's app bar.

| Demo | What it shows |
|---|---|
| Default | No options. Colors come from the app's `ColorScheme`, so switching the seed color on the demos screen changes the editor's accent. |
| Custom theme | `ChatImageEditorThemeData` color and text overrides, custom `ChatImageEditorIcons` and a `sendButton` builder that reads `ChatImageEditorScope`. |
| Done mode | `ChatImageEditorMode.done`: no caption, a single done button and PNG export. |
| Size limit | `ExportOptions(maxBytes: 300 * 1024, maxLongEdge: 1600)`. |
| Localized | A Spanish `ChatImageEditorStrings`, a decimal-comma byte formatter and a caption header. |
| Controller | `ChatImageEditor` embedded in a screen and driven by an external `ChatImageEditorController`: rotate, flip, draw, add text, undo, redo, clear and export from code. |

Every demo ends on a result screen with the edited image, caption,
dimensions, format and file size.

The demos screen also has a light/dark switch and a seed color picker for the
whole app, chat included.

## Code map

| File | Contents |
|---|---|
| `lib/src/chat/chat_photo_editor.dart` | How the chat opens the editor: export limits, caption and stats logging. |
| `lib/src/chat/chat_screen.dart` | The chat: message list, photo picking and sending. |
| `lib/src/chat/message_bubble.dart` | Text and photo bubbles, with thumbnails decoded at bubble size. |
| `lib/src/chat/photo_viewer_screen.dart` | Full-screen photo with its `ExportStats`. |
| `lib/src/chat/conversation.dart` | The chat's messages, newest first. |
| `lib/src/demos/` | One file per demo, plus `demo.dart` listing them. |
| `lib/src/demos_screen.dart` | Image picking, appearance settings and the demo list. |
| `lib/src/result_screen.dart` | Shows a `ChatImageEditorResult`. |
| `lib/src/sample_image.dart` | Draws and encodes the sample image. |
| `integration_test/editor_performance_test.dart` | Frame timings of drawing, text dragging, cropping and zooming. |
| `test_driver/perf_driver.dart` | Writes each frame-timing report to `build/<reportKey>.timeline_summary.json`. |

## Frame performance test

Run on a real device in profile mode:

```bash
fvm flutter drive --driver=test_driver/perf_driver.dart \
  --target=integration_test/editor_performance_test.dart --profile -d <device>
```

See [doc/PERFORMANCE.md](../doc/PERFORMANCE.md) for what the summaries
mean.

## Platform setup for image_picker

- **iOS**: `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` in
  `ios/Runner/Info.plist`.
- **macOS**: `com.apple.security.files.user-selected.read-only` in both
  `macos/Runner/DebugProfile.entitlements` and
  `macos/Runner/Release.entitlements`. The camera button is hidden on
  desktop, where `image_picker` has no camera support out of the box.
  `DebugProfile.entitlements` also has
  `com.apple.security.network.client`, which the frame performance test
  needs to reach the VM service from inside the sandbox.
- **Android** and **web**: no extra setup.
