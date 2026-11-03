# Architecture

`chat_image_editor` is a pure-Dart Flutter package. Every pixel is drawn with
`CustomPaint` and `dart:ui`; there's no platform code, so it runs on Android,
iOS, web, macOS, Windows and Linux.

## Design principles

1. **Edits are data, not pixels.** The source image is decoded once. Every
   edit (stroke, text, crop, rotation, flip, quality) is plain immutable data
   in an `ImageEditValue`. Pixels are produced only at export.
2. **One coordinate system for edits.** Strokes and text layers are stored in
   *normalized original-image space* (`0..1` over the source photo). Sizes
   (stroke width, font size) are fractions of the image's shortest side. Edits
   therefore stay glued to the picture through crop, rotate and flip, and
   export sharply at any resolution.
3. **One transform for everything.** `ImageGeometry` is the only code that
   knows how original space maps to the screen and to the output. The canvas,
   gesture mapping and export all use it.
4. **One renderer for everything.** The live canvas and the export both call
   `CompositionRenderer.paint`. The export is the preview, rendered at a
   different scale.

## Coordinate spaces

```
original space      normalized 0..1 over the decoded source image
      │  flip (flipX / flipY)
      │  rotate clockwise by quarterTurns × 90°
      ▼
transformed space   the flipped + rotated image; crop is normalized here
      │  crop
      ▼
output / view space what the user sees and what gets exported
```

"Output pixels" have their origin at the crop's top-left and one unit per
original-image pixel. The canvas scales output pixels to fit the screen; the
exporter scales them to honour `ExportOptions.maxLongEdge`.

## Layers

```
lib/
  chat_image_editor.dart        public exports
  src/
    models/                     immutable data: Stroke, TextLayer, ImageEditValue, enums
    config/                     ChatImageEditorConfig, ExportOptions, CaptionFieldConfig, builders
    theme/                      theme data + resolution, icons, strings, ChatImageEditorScope
    core/
      geometry/                 ImageGeometry
      render/                   StrokeRenderer, TextRenderer, CompositionRenderer
      encoding/                 ImageEncoder interface, DartImageEncoder (package:image)
      export/                   result type, exporter (render → raw RGBA → encode → size target)
      loading/                  capped decoding of the source bytes
      history/                  undo/redo stack of ImageEditValue snapshots
    controller/                 ChatImageEditorController (ChangeNotifier): all state + actions
    ui/                         widgets only; read state from the controller, never store edits
```

Dependencies point downwards only: `ui → controller → core → models`.
`core` never imports `ui`. Widgets never compute geometry themselves.

## Theming

`ChatImageEditorThemeData.resolve(context, override)` produces a
`ChatImageEditorResolvedTheme` with every value filled in, in this order:

1. the `theme` passed to `ChatImageEditor`,
2. a `ChatImageEditorThemeData` registered in the app's `ThemeData.extensions`,
3. defaults derived from the app's `ColorScheme` (accents use `primary`).

Widgets read the resolved theme, icons, strings and config from
`ChatImageEditorScope.of(context)` and never hard-code colors.

## Export pipeline

```
source bytes ── decode at the needed size (ImageDescriptor, capped by maxLongEdge)
   → PictureRecorder canvas sized to the output
   → JPEG only: fill backgroundColor
   → scale(outputScale) → CompositionRenderer.paint(...)
   → Picture.toImage → toByteData(rawStraightRgba)
   → ImageEncoder.encode (JPEG at the chosen quality, or PNG)
   → maxBytes set and too big? step JPEG quality down to minQuality
   → ChatImageEditorResult
```

## History

Undo/redo stores whole `ImageEditValue` snapshots. Lists are immutable and
shared between snapshots, so a snapshot costs a few pointers. A history
entry is recorded per completed user action, never per pointer event.

## Contracts

These files form the public contract and are changed deliberately, in their
own commit, before implementation work that depends on them:

- everything in `lib/src/models/`, `lib/src/config/`, `lib/src/theme/`
- public signatures in `lib/src/core/**`, `lib/src/controller/` and
  `lib/src/ui/chat_image_editor.dart`
