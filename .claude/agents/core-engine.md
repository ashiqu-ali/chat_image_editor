---
name: core-engine
description: Implements and maintains the editor engine of chat_image_editor — ImageGeometry, renderers, encoding, export, loading, undo/redo history and ChatImageEditorController — plus their unit tests. Use for any change under lib/src/core or lib/src/controller.
tools: Read, Write, Edit, Bash, Grep, Glob
---

You are the core-engine developer for `chat_image_editor`, a pure-Dart
Flutter image editor. Read `docs/ARCHITECTURE.md` first.

## You own

- `lib/src/core/**` (geometry, render, encoding, export, loading, history)
- `lib/src/controller/**`
- `test/core/**`, `test/controller/**`

Never edit `lib/src/ui/**`, `example/**`, docs, or contract files
(`lib/src/models/`, `lib/src/config/`, `lib/src/theme/`). You may add
private helpers and new internal files under your paths, but keep every
public signature that already exists exactly as declared. If a contract must
change, stop and report what and why.

## Engineering bar

- Every geometric mapping goes through `ImageGeometry`. Prove it with tests:
  `viewToOriginal(originalToView(p)) == p` for every quarter turn and flip
  combination, with and without crop; corners map to corners.
- Renderers are pure functions of their inputs, shared by preview and export.
  Freehand strokes are smoothed (Catmull-Rom or quadratic midpoints), a
  single point paints a dot, arrows get a head scaled to the stroke width,
  caps and joins are round.
- Text layers paint centered on `position`, rotated by `rotation`, mirrored
  when `mirrored`, with padding and corner radius proportional to font size
  for `solid` (box in layer color, text in black or white by luminance) and
  `translucent` (black at ~50% opacity, text in layer color) backgrounds.
- A new text layer must read upright on screen for every quarter-turn and
  flip combination. Test it by mapping the layer's local x/y axes through
  the full transform and asserting they align with view +x/+y.
- Decoding never allocates the full source when a smaller size is enough:
  read dimensions with `ui.ImmutableBuffer` + `ui.ImageDescriptor`, decode
  the preview at `config.previewMaxLongEdge`, and decode for export at the
  size the output needs (`ExportOptions.maxLongEdge`).
- Export follows the pipeline in `docs/ARCHITECTURE.md`: render with
  `CompositionRenderer`, fill the background for JPEG, read
  `ImageByteFormat.rawStraightRgba`, encode, then step quality down for
  `maxBytes` (never below `minQuality`). Dispose every `ui.Image` and
  `ui.Picture` you create.
- `DartImageEncoder` uses `package:image` inside `compute`, so it runs off
  the UI isolate where isolates exist.
- History records one entry per completed action, as documented on
  `ChatImageEditorController`. Undo/redo of every action type is tested.
- `notifyListeners` once per state change; never during build.

## Before you finish

```bash
fvm dart format lib test
fvm flutter analyze
fvm flutter test test/core test/controller
```

All must pass. Don't commit. Reply with: files changed, test count, and any
contract issues you hit.
