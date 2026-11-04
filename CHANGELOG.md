# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0]

### Added

- `ChatImageEditor` widget and `ChatImageEditor.open` route helper that
  returns a `ChatImageEditorResult` with the encoded bytes, size, format,
  caption and edits.
- Send mode (a full-width caption, with the caption header in a chip beside
  the send button) and done mode (single done button).
- Draw tool: freehand, line, rectangle, circle and arrow, a brush size
  slider and a vertical gradient color slider. The top bar turns into a
  **Done** pill, undo and a swatch of the pen color while drawing.
- Text tool: add, edit, move, pinch to resize and rotate, drag to delete,
  center alignment guides and background styles, with a **Done** pill and
  the color slider while typing.
- Crop with aspect-ratio presets, rotate, flip and reset in one bottom row.
  The back button or gesture cancels the crop (and closes text entry or the
  compress sheet) instead of closing the editor.
- Compression with a quality sheet in steps of 10 labelled Low, Medium or
  High, the original size, a live size estimate, an **Apply** button, and a
  `maxBytes` target.
- Undo and redo for every edit.
- Pinch-to-zoom while no tool is open, and a discard prompt for unsaved
  edits that uses the platform's style: a Cupertino alert on iOS and macOS,
  a Material dialog elsewhere.
- `ChatImageEditorConfig.hideSystemBarsWhileDrawing` (off by default) to
  hide the status and navigation bars while drawing.
- Theming that defaults to the host app's `ColorScheme`, with per-field
  overrides through `ChatImageEditorThemeData`, also usable as a
  `ThemeExtension`.
- Replaceable icons, strings (including `color`, `apply` and
  `formatQuality`) and caption `TextFormField` configuration.
- Builders that replace the top bar, bottom bar, send and done buttons,
  loading and error views, and the discard dialog.
- `ChatImageEditorController` to drive the editor from code and read its
  state.
- `sendEnabled` and `onSendLongPress` to control the send button.
- Export options: JPEG or PNG, quality, `maxLongEdge` and `maxBytes`.
- Pure-Dart JPEG/PNG encoding through a pluggable `ImageEncoder`.
- `ExportStats` in `ChatImageEditorResult.stats`: decode, render, encode and
  total time, encode attempts, final quality, and source and output sizes,
  for apps to log export performance to their own analytics.
- `chat_image_editor.*` timeline spans around loading, decoding, painting,
  rendering, rasterizing, encoding, the `maxBytes` search and size
  estimates, visible in the Performance view of Flutter DevTools and
  compiled out of release builds.
- A benchmark suite (`fvm flutter test benchmark`) with a Markdown report
  tool (`tool/benchmark_report.dart`), and frame-timing integration tests
  for drawing, text dragging, cropping and zooming in the example app.
- An example app built as a chat: pick a photo, edit it and send it; each
  bubble shows the file size and export time, and the photo viewer shows
  the full `ExportStats`.
