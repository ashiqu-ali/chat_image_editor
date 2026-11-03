# chat_image_editor example

A small app that shows every customization option of `chat_image_editor`.

```bash
fvm flutter pub get
fvm flutter run
```

It works with zero setup: the default image is a landscape drawn with
`dart:ui` when you open a demo. You can also pick a photo from the gallery or
take one with the camera (where the platform supports it).

## Demos

| Demo | What it shows |
|---|---|
| Default | No options. Colors come from the app's `ColorScheme`, so switching the seed color on the home screen changes the editor's accent. |
| Custom theme | `ChatImageEditorThemeData` color and text overrides, custom `ChatImageEditorIcons` and a `sendButton` builder that reads `ChatImageEditorScope`. |
| Done mode | `ChatImageEditorMode.done`: no caption, a single done button and PNG export. |
| Size limit | `ExportOptions(maxBytes: 300 * 1024, maxLongEdge: 1600)`. |
| Localized | A Spanish `ChatImageEditorStrings`, a decimal-comma byte formatter and a caption header. |
| Controller | `ChatImageEditor` embedded in a screen and driven by an external `ChatImageEditorController`: rotate, flip, draw, add text, undo, redo, clear and export from code. |

Every demo ends on a result screen with the edited image, caption,
dimensions, format and file size.

The home screen also has a light/dark switch and a seed color picker for the
whole app.

## Code map

| File | Contents |
|---|---|
| `lib/src/demos/` | One file per demo, plus `demo.dart` listing them. |
| `lib/src/home_screen.dart` | Image picking, appearance settings and the demo list. |
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

See [docs/PERFORMANCE.md](../docs/PERFORMANCE.md) for what the summaries
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
