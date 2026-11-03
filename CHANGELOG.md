# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

### Added

- `ChatImageEditor` widget and `ChatImageEditor.open` route helper.
- Draw tool: freehand, line, rectangle, circle and arrow.
- Text tool: add, edit, move, pinch to resize and rotate, drag to delete,
  background styles.
- Crop, rotate and flip.
- Compression with a quality slider, live size estimate and a `maxBytes` target.
- Undo and redo for every edit.
- Theming that defaults to the host app's `ColorScheme`, with per-field
  overrides through `ChatImageEditorThemeData`.
- Replaceable icons, strings and caption `TextFormField` configuration.
- Pure-Dart JPEG/PNG encoding through a pluggable `ImageEncoder`.
