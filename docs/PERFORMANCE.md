# Performance

Editing a photo in a chat app has two moments where speed matters: the
gestures (drawing, moving text, cropping, zooming) must stay at full frame
rate, and the send button must not keep the user waiting for the export.
This page describes how the package measures both, and how to tune it.

There are four tools, from the app in the field to the lab:

| Tool | Answers | Where it runs |
|---|---|---|
| [`ChatImageEditorResult.stats`](#export-stats-in-your-app) | How long did this user's export take, and why? | Your app, every export |
| [Timeline spans](#timeline-spans-in-devtools) | Where does the time go in one export or frame? | DevTools, while you profile |
| [Benchmarks](#benchmarks) | Did this change make the hot paths slower? | Your machine and CI |
| [Frame tests](#frame-tests-on-a-device) | Do the gestures stay smooth? | A real device |

## Export stats in your app

Every result from the editor carries an `ExportStats` in `result.stats`:

| Field | Meaning |
|---|---|
| `decodeTime` | Decoding the source bytes at the size the output needs. |
| `renderTime` | Painting the edits over the decoded image and reading back the pixels. |
| `encodeTime` | Encoding, summed over every attempt. |
| `totalTime` | The whole export, at least the sum of the three phases. |
| `encodeAttempts` | Encoder runs: `1`, or more when `maxBytes` stepped quality down. |
| `finalQuality` | JPEG quality of the returned bytes; `null` for PNG. |
| `sourceByteLength` | Size of the image you passed to the editor. |
| `outputByteLength` | Size of `result.bytes`. |
| `outputWidth`, `outputHeight` | Pixel size of the result. |

Log them with whatever analytics or logging your app already uses. The
package itself sends nothing anywhere; the numbers only exist in the result
you receive.

```dart
final result = await ChatImageEditor.open(context, photo);
final stats = result?.stats;
if (stats != null) {
  analytics.logEvent('image_export', {
    'total_ms': stats.totalTime.inMilliseconds,
    'decode_ms': stats.decodeTime.inMilliseconds,
    'render_ms': stats.renderTime.inMilliseconds,
    'encode_ms': stats.encodeTime.inMilliseconds,
    'attempts': stats.encodeAttempts,
    'quality': stats.finalQuality,
    'source_bytes': stats.sourceByteLength,
    'output_bytes': stats.outputByteLength,
    'megapixels': stats.outputWidth * stats.outputHeight / 1e6,
  });
}
```

How to read them:

- `encodeTime` dominates on most devices with the built-in pure-Dart
  encoder. If it's high, lower `maxLongEdge` or plug in a native
  `ImageEncoder` (see the README).
- `encodeAttempts` above 1 means the `maxBytes` ladder ran; each extra
  attempt is a full re-encode (see [tips](#tips)).
- `decodeTime` grows with the source size, not the output size; very large
  sources (panoramas, 50 MP cameras) show up here.
- `totalTime` much larger than the three phases together means the device
  was busy with something else (for example the UI thread was blocked).

`ChatImageEditorController.export()` returns the same result, so the stats
are there when you drive the editor from code too. A
`ChatImageEditorResult` you build yourself has `stats: null`.

## Timeline spans in DevTools

The expensive steps are wrapped in `dart:developer` timeline spans whose
names start with `chat_image_editor.`. Async work uses `TimelineTask` spans;
synchronous work uses `Timeline.timeSync`. Release builds compile the spans
out, so they cost nothing in production.

To see them:

1. Run the app in profile mode on a device: `fvm flutter run --profile`.
2. Open DevTools and go to the **Performance** page.
3. Use the editor (draw, export, open the compress tool), then open the
   **Timeline Events** tab and search for `chat_image_editor`.

Async spans appear on their own async tracks; a child span has a
`parentId` argument pointing at the span that started it. Synchronous
spans appear on the thread that ran them.

| Span | Kind | Covers | Arguments |
|---|---|---|---|
| `chat_image_editor.load` | async | `ChatImageEditorController.load`: decoding the preview | `bytes`, `previewMaxLongEdge`; at the end `outcome`, preview and original size |
| `chat_image_editor.decode` | async | Any decode of encoded bytes, for the preview or an export | `bytes`, `maxLongEdge`; at the end decoded and original size |
| `chat_image_editor.export` | async | A whole export | `sourceBytes`, `format`, `quality`, `maxLongEdge`, `maxBytes`, `strokes`, `texts`; at the end every `ExportStats` value |
| `chat_image_editor.render` | async, under `export` | Decoding, painting and reading back the export pixels | `width`, `height`, `decodeLongEdge`, `strokes`, `texts` |
| `chat_image_editor.paint` | sync, UI thread | One `CompositionRenderer.paint`: every preview frame and the export picture | `strokes`, `texts`, `draft`, `imageWidth`, `imageHeight` |
| `chat_image_editor.rasterize` | async, under `render` | `Picture.toImage` plus reading the RGBA bytes | `width`, `height` |
| `chat_image_editor.encode` | async, under `export` or `fit_max_bytes` | One encoder call | `format`, `quality`, `attempt`, `width`, `height`; at the end `bytes` |
| `chat_image_editor.encode_pixels` | sync, encoder isolate | The pixel work inside `DartImageEncoder` (on the main thread on the web) | `format`, `quality`, `width`, `height` |
| `chat_image_editor.fit_max_bytes` | async, under `export` | The `maxBytes` quality ladder after the first attempt was too big | `maxBytes`, `firstBytes`, `startQuality`, `minQuality`; at the end `attempts`, `finalQuality`, `bytes`, `exceedsMaxBytes` |
| `chat_image_editor.estimate_size` | async | A compress-tool size estimate that wasn't cached, including time queued behind other estimates | `format`, `quality`, `renderCached`; at the end `bytes` |

Things to look for:

- `paint` longer than a few milliseconds per frame: too many strokes or
  text layers for the device. It runs inside the frame's paint phase, so it
  adds directly to the frame build time.
- A gap between `encode` and `encode_pixels`: the time to start the
  background isolate and copy the pixels to it.
- Several `encode` spans under `fit_max_bytes`: the size target is costing
  re-encodes.

## Benchmarks

The `benchmark/` folder measures the hot paths on the host machine, using a
synthesized photo (a 4032×3024 noisy gradient JPEG generated with
`package:image` at the start of the run; nothing is downloaded or checked
in). Run from the package root:

```bash
fvm flutter test benchmark
fvm dart run tool/benchmark_report.dart build/benchmark/results.json
```

The first command runs every benchmark in one process, one after another,
and writes `build/benchmark/results.json`. The second prints it as a
Markdown table. A run takes under a minute on a recent laptop. CI runs the
same two commands and adds the table to the job summary.

| Benchmark | Measures |
|---|---|
| `geometry: viewToOriginal x100k` | 100,000 point mappings through crop, rotation and flip (the per-pointer-event cost). |
| `paint: 200 strokes (record)` | `CompositionRenderer.paint` of 200 strokes into a `PictureRecorder`: the UI-thread part of one preview frame. |
| `load: 12 MP JPEG preview` | `ChatImageEditorController.load` of the 12 MP photo at `previewMaxLongEdge` 2048. |
| `encode: JPEG q90 2048x1536` | `DartImageEncoder` JPEG, including the background isolate hop. |
| `encode: PNG 2048x1536` | `DartImageEncoder` PNG of the same pixels. |
| `export: JPEG q90, maxLongEdge 4096` | A full export with 50 strokes and 3 text layers over the 12 MP photo. |
| `export: maxBytes ladder` | The same export with `maxBytes` just below the quality-70 size, so it encodes at 90, 80, 70 and 60. |
| `estimateSize: first call` | A size estimate after an edit: render plus one encode. |
| `estimateSize: new quality` | A new slider position: the render is cached, one encode. |
| `estimateSize: cached` | A quality that was already estimated. |

Each benchmark first runs a few unmeasured warm-up iterations, then times N
iterations with a `Stopwatch`. Heavy benchmarks use fewer iterations.

### Reading the report

Two rows from a run on a laptop:

```
| Benchmark | Iterations | Mean (ms) | p50 (ms) | p90 (ms) | Min (ms) | Max (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| load: 12 MP JPEG preview | 10 | 76.85 | 77.07 | 80.33 | 73.36 | 80.59 |
| export: JPEG q90, maxLongEdge 4096 | 8 | 708.6 | 693.9 | 774.1 | 654.0 | 774.5 |
```

- **Iterations** is the number of measured runs (warm-up excluded).
- **p50** is the median: the typical run. Compare p50 between commits.
- **p90** is the slow end, interpolated between the two nearest runs. With
  few iterations it sits close to the maximum.
- **Mean** is pulled up by outliers (garbage collection, a busy machine);
  a mean far above the p50 means the runs were noisy.
- **Min** and **Max** show the spread.
- The **Memory** section reports the process's resident set size (RSS)
  before and after the export benchmarks, the change, and the peak for the
  whole run. A growing "after" across commits points at retained buffers.
- The **Notes** list says what each benchmark did, and for exports the mean
  decode, render and encode split taken from `ExportStats`.

Keep in mind:

- `flutter test` runs Dart in debug (JIT) mode with assertions on, inside
  the headless test engine on the host. The numbers are for comparing
  commits on the same machine, not for predicting what a phone does.
- Shared CI machines are noisy, so CI reports the results without failing
  on them. Look for consistent shifts, not single runs.

## Frame tests on a device

`example/integration_test/editor_performance_test.dart` opens the editor on
the example's generated sample image and records frame timings with
`IntegrationTestWidgetsFlutterBinding.watchPerformance` around four
gestures:

| Report key | Gesture |
|---|---|
| `draw_strokes` | Four long freehand strokes, one pointer move per frame. |
| `drag_text` | Dragging a text layer in a loop and then to the side. |
| `crop_handle` | Pulling a crop corner in towards the center and partly back. |
| `pinch_zoom` | Two-finger zoom in and back out on the preview. |

Run it in profile mode on a real device, from `example/`:

```bash
fvm flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/editor_performance_test.dart \
  --profile -d <device>
```

`test_driver/perf_driver.dart` writes one file per gesture,
`build/<reportKey>.timeline_summary.json` (for example
`build/draw_strokes.timeline_summary.json`), or under
`$FLUTTER_TEST_OUTPUTS_DIR` when that's set. If the driver can't connect to
the app's VM service, add `--no-dds`.

The same test also runs as a plain test, which checks that the gestures
work but writes no files:

```bash
fvm flutter test integration_test -d <device>
```

On macOS the test needs to reach the VM service from inside the app
sandbox, so the example's `macos/Runner/DebugProfile.entitlements` (debug
and profile builds only) includes `com.apple.security.network.client`.

### What the summary fields mean

Times are in milliseconds. "Build" is the UI thread's work for a frame
(build, layout, and painting into a picture, including
`chat_image_editor.paint`). "Rasterizer" is the raster thread's work to
draw that picture on the GPU. Each must fit the frame budget, or the frame
is late.

| Field | Meaning |
|---|---|
| `frame_count` | Frames drawn during the gesture. |
| `average_frame_build_time_millis` | Mean UI-thread time per frame. |
| `90th_percentile_frame_build_time_millis` | 90% of frames built at least this fast. |
| `99th_percentile_frame_build_time_millis` | The slowest 1% start here; this is where jank shows. |
| `worst_frame_build_time_millis` | The single slowest build. |
| `missed_frame_build_budget_count` | Frames whose build took longer than 16 ms. |
| `average_frame_rasterizer_time_millis`, `90th_…`, `99th_…`, `worst_…` | The same for the raster thread. |
| `missed_frame_rasterizer_budget_count` | Frames whose raster took longer than 16 ms. |
| `new_gen_gc_count`, `old_gen_gc_count` | Garbage collections during the gesture. |
| `frame_build_times`, `frame_rasterizer_times` | Every frame's time, in microseconds. |

The 16 ms budget assumes a 60 Hz display. On a 90 or 120 Hz screen the
real budget is 11 or 8 ms, so compare the percentiles against that rather
than relying on the missed-budget counts. Healthy editing keeps the 90th
percentiles of both threads well under the budget and the missed counts
at or near zero.

## Tips

- **Measure in profile mode on a real device.** Debug mode runs Dart in a
  JIT with assertions and is often several times slower; simulators and
  emulators don't reflect a phone's GPU or memory. Use debug only to check
  that something works.
- **`maxLongEdge` sets the export cost.** Decode, render and encode all
  scale with the output pixel count. The default 4096 keeps a 4:3 photo at
  up to 4096×3072 (12.6 megapixels); 2048 cuts that by four, which makes
  exports several times faster and is still sharp in a chat bubble.
- **`previewMaxLongEdge` sets the editing cost.** It caps the image decoded
  for the screen (2048 by default, about 12 MB of pixels). Lower it for
  low-memory devices; raise it only if zoomed-in previews look soft. The
  export always re-decodes the source, so it doesn't change the result.
- **`maxBytes` can multiply the encode time.** When the first attempt is
  too big, every step down the quality ladder is a full re-encode: from
  quality 90 down to the default `minQuality` 30 that is up to seven
  encodes. To keep it to one or two, start at a lower `quality`, raise
  `minQuality`, or lower `maxLongEdge` so the first attempt usually fits.
  `result.stats.encodeAttempts` shows how often this happens in the field.
- **Size estimates are cached.** The compress tool renders once per edit
  state and encodes once per quality; moving the slider back to a quality
  it already showed is free.
- **A native encoder is the biggest single win** for large exports; see
  "Custom encoder" in the README.
