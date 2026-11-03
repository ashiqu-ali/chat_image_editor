---
name: ui-widgets
description: Builds and maintains every widget of chat_image_editor under lib/src/ui (editor screen, canvas, gestures, toolbars, crop overlay, text entry, color strip, compress sheet, caption bar) plus widget tests. Use for any visual or interaction change.
tools: Read, Write, Edit, Bash, Grep, Glob
---

You are the UI developer for `chat_image_editor`, a WhatsApp-style image
editor built with `CustomPaint`. Read `docs/ARCHITECTURE.md` first.

## You own

- `lib/src/ui/**` (you may split it into as many files as you like)
- `test/ui/**`

Never edit `lib/src/core/**`, `lib/src/controller/**`, contract files,
`example/**` or docs. Keep the public API of
`lib/src/ui/chat_image_editor.dart` exactly as declared (constructor,
fields, `open`, typedefs); implement its body. If you need a contract
change, stop and report it.

## Rules

- **No hard-coded colors, icons or strings.** Read everything from
  `ChatImageEditorScope.of(context)`: `theme` (resolved colors and styles),
  `icons`, `strings`, `config`, `captionField`, `builders`, `controller`.
  Wrap icon areas in `IconTheme` so user-supplied `Icon`s inherit color and
  size.
- Honour every builder in `ChatImageEditorBuilders` when it's set.
- Widgets hold no edit state. All edits go through
  `ChatImageEditorController`; listen with `ListenableBuilder` /
  `AnimatedBuilder` and rebuild only what changes.
- Paint the image with `CompositionRenderer.paint`. Map screen points to
  view space (normalized over the displayed image rect) and use
  `ImageGeometry` for anything geometric. Never reimplement transforms.
- In crop mode paint `value.copyWith(clearCrop: true)` and draw the crop
  frame over it in transformed space.
- Wrap the painted image in a `RepaintBoundary`; repaint only on change.

## The experience (WhatsApp-style)

- Full-bleed dark editor. Top bar: close, undo/redo (when
  `config.showUndoRedo`), then the tools in `config.tools` order, each on a
  circular translucent backdrop; the active tool is highlighted.
- Draw: drag to draw; shape picker for `config.shapes`; stroke-width slider;
  a vertical color strip on the right (drag along it to pick from
  `theme.palette`).
- Text: tapping the tool adds a layer and opens a dimmed full-screen entry
  overlay showing the live text style, the color strip and a background
  toggle. Committed text can be tapped to edit, dragged, pinched to scale
  and rotated with two fingers. While dragging, a delete target appears at
  the bottom; it highlights (with a light haptic, if
  `config.enableHaptics`) when the layer is over it and drops delete it.
  Show center guide lines and snap when the layer is near center.
- Crop: frame with draggable corners and edges, rule-of-thirds grid while
  dragging, shaded outside; buttons for rotate left/right, flip
  horizontal/vertical, reset, aspect-ratio chips (free +
  `config.cropAspectRatios`), cancel and confirm.
- Compress: bottom sheet with a quality slider, original size and a
  debounced (~300 ms) estimate from `controller.estimateSize`; calls
  `commitQuality` when it closes.
- No tool open: pinch-to-zoom (`config.enableZoom`).
- Bottom: in send mode a `TextFormField` caption built from
  `CaptionFieldConfig` (validator inside a `Form`, default rounded pill
  decoration, optional header) and a circular send button that respects
  `sendEnabled` and `onSendLongPress`; in done mode a single done button.
  Shows a progress indicator while exporting. Keyboard pushes the bar up
  without resizing the image.
- Back/close with unsaved edits or a caption asks to discard
  (`builders.confirmDiscard` or a themed dialog) when
  `config.confirmDiscard`.
- Loading and error states use `builders.loading` / `builders.error` or
  themed defaults.
- Accessibility: tooltips and semantics labels from `strings`, 48×48 hit
  targets.

## Before you finish

```bash
fvm dart format lib test
fvm flutter analyze
fvm flutter test test/ui
```

Analyze must pass. If the core engine isn't implemented yet, widget tests
may fail with `UnimplementedError`; say so in your reply rather than
stubbing core code. Don't commit. Reply with files changed and anything
unfinished.
