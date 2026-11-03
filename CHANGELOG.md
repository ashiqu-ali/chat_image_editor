# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

### Added

- `ChatImageEditor` widget and `ChatImageEditor.open` route helper that
  returns a `ChatImageEditorResult` with the encoded bytes, size, format,
  caption and edits.
- Send mode (caption and send button) and done mode (single done button).
- Draw tool: freehand, line, rectangle, circle and arrow, with a brush size
  slider and a color strip.
- Text tool: add, edit, move, pinch to resize and rotate, drag to delete,
  center snap guides and background styles.
- Crop with aspect-ratio presets, rotate and flip.
- Compression with a quality slider, live size estimate and a `maxBytes`
  target.
- Undo and redo for every edit.
- Pinch-to-zoom while no tool is open, and a discard prompt for unsaved
  edits.
- Theming that defaults to the host app's `ColorScheme`, with per-field
  overrides through `ChatImageEditorThemeData`, also usable as a
  `ThemeExtension`.
- Replaceable icons, strings and caption `TextFormField` configuration.
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
