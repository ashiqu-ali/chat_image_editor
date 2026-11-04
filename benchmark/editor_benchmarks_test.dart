// Benchmarks for the editor's expensive paths. Run from the package root:
//
//   fvm flutter test benchmark
//   fvm dart run tool/benchmark_report.dart build/benchmark/results.json
//
// Every benchmark lives in this one file so they run one after another in
// a single process (never in parallel with each other) and the results land
// in a single build/benchmark/results.json. See doc/PERFORMANCE.md.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/fixtures.dart';
import 'src/harness.dart';

/// Where the results are written, relative to the package root.
final File resultsFile = File('build/benchmark/results.json');

void main() {
  final report = BenchmarkReport();

  // The synthesized 12 MP source photo, created once.
  late Uint8List photo;

  // A loaded controller whose preview image the paint benchmark draws.
  late ChatImageEditorController previewEditor;

  setUpAll(() async {
    photo = synthesizePhotoJpeg();
    previewEditor = ChatImageEditorController();
    await previewEditor.load(photo);
    expect(previewEditor.loadStatus, ImageLoadStatus.ready);
  });

  tearDownAll(() async {
    previewEditor.dispose();
    final before = report.memory['rssBeforeExportBytes'];
    final after = report.memory['rssAfterExportBytes'];
    if (before != null && after != null) {
      report.memory['rssDeltaExportBytes'] = after - before;
    }
    report.memory['maxRssBytes'] = ProcessInfo.maxRss;
    await report.write(resultsFile);
  });

  test('ImageGeometry.viewToOriginal throughput', () {
    const calls = 100000;
    final size = Size(photoWidth.toDouble(), photoHeight.toDouble());
    const value = ImageEditValue(
      quarterTurns: 1,
      flipX: true,
      crop: Rect.fromLTRB(0.1, 0.2, 0.9, 0.7),
    );
    var sink = 0.0;
    final samples = sampleSync(
      () {
        for (var i = 0; i < calls; i++) {
          final point = ImageGeometry.viewToOriginal(
            Offset((i % 1000) / 1000, (i % 777) / 777),
            size,
            value,
          );
          sink += point.dx + point.dy;
        }
      },
      warmUp: 5,
      iterations: 20,
    );
    // Using the result keeps the loop from being optimized away.
    expect(sink.isFinite, isTrue);
    final result = BenchmarkResult.fromSamples(
      'geometry: viewToOriginal x100k',
      samples,
      notes:
          '100,000 calls per iteration with crop, a quarter turn and a flip; '
          '${_ns(samples, calls)} ns per call on average.',
    );
    report.add(result);
  });

  test('CompositionRenderer.paint of 200 strokes', () {
    final preview = previewEditor.image!;
    final original = previewEditor.originalSize;
    final value = ImageEditValue(strokes: syntheticStrokes(200));
    // Draw at the scale of a phone screen 1170 px wide, as the canvas does.
    final scale = 1170 / original.width;
    final samples = sampleSync(
      () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(scale);
        CompositionRenderer.paint(
          canvas,
          image: preview,
          originalSize: original,
          value: value,
          textStyle: previewEditor.textLayerStyle,
        );
        recorder.endRecording().dispose();
      },
      warmUp: 20,
      iterations: 200,
    );
    report.add(
      BenchmarkResult.fromSamples(
        'paint: 200 strokes (record)',
        samples,
        notes:
            'Records one preview frame (${preview.width}x${preview.height} '
            'preview, 200 strokes of up to 40 points) into a PictureRecorder; '
            'rasterization is not included.',
      ),
    );
  });

  test('load (preview decode) of a 12 MP JPEG', () async {
    final samples = await sampleAsync(
      (_) async {
        final editor = ChatImageEditorController();
        try {
          final ms = await timeAsync(() => editor.load(photo));
          expect(editor.loadStatus, ImageLoadStatus.ready);
          return ms;
        } finally {
          editor.dispose();
        }
      },
      warmUp: 2,
      iterations: 10,
    );
    report.add(
      BenchmarkResult.fromSamples(
        'load: 12 MP JPEG preview',
        samples,
        notes:
            '${photoWidth}x$photoHeight JPEG (${_mb(photo.length)}) decoded '
            'for editing at previewMaxLongEdge 2048.',
      ),
    );
  });

  group('DartImageEncoder', () {
    const width = 2048;
    const height = 1536;
    const encoder = DartImageEncoder();
    late RgbaImage pixels;

    setUpAll(() {
      pixels = RgbaImage(
        pixels: photoPixels(width, height),
        width: width,
        height: height,
      );
    });

    for (final format in ExportFormat.values) {
      final jpeg = format == ExportFormat.jpeg;
      test('${format.name} at ${width}x$height', () async {
        var outputBytes = 0;
        final samples = await sampleAsync(
          (_) => timeAsync(() async {
            final bytes = await encoder.encode(
              pixels,
              format: format,
              quality: 90,
            );
            outputBytes = bytes.length;
          }),
          warmUp: jpeg ? 2 : 1,
          iterations: jpeg ? 8 : 5,
        );
        report.add(
          BenchmarkResult.fromSamples(
            jpeg
                ? 'encode: JPEG q90 ${width}x$height'
                : 'encode: PNG ${width}x$height',
            samples,
            notes:
                'Opaque photo-like RGBA, encoded on a background isolate '
                'into ${_mb(outputBytes)}.',
          ),
        );
      });
    }
  });

  group('export', () {
    late ChatImageEditorController editor;
    final edits = ImageEditValue(
      strokes: syntheticStrokes(50),
      texts: syntheticTexts(),
    );

    setUpAll(() async {
      report.recordRss('rssBeforeExportBytes');
      editor = ChatImageEditorController(initialValue: edits);
      await editor.load(photo);
      expect(editor.loadStatus, ImageLoadStatus.ready);
    });

    tearDownAll(() {
      report.recordRss('rssAfterExportBytes');
      editor.dispose();
    });

    test('with the default options', () async {
      const warmUp = 2;
      final stats = <ExportStats>[];
      final samples = await sampleAsync(
        (iteration) => timeAsync(() async {
          final result = await editor.export();
          if (iteration >= warmUp) stats.add(result!.stats!);
        }),
        warmUp: warmUp,
        iterations: 8,
      );
      final last = stats.last;
      report.add(
        BenchmarkResult.fromSamples(
          'export: JPEG q90, maxLongEdge 4096',
          samples,
          notes:
              '50 strokes and 3 text layers over the 12 MP photo into a '
              '${last.outputWidth}x${last.outputHeight} JPEG of '
              '${_mb(last.outputByteLength)}; ${_phases(stats)}.',
        ),
      );
    });

    test('with maxBytes forcing the quality ladder', () async {
      const defaults = ChatImageEditorConfig();
      // Just under the quality-70 size: 90, 80 and 70 miss, 60 fits.
      editor.config = const ChatImageEditorConfig(
        export: ExportOptions(quality: 70),
      );
      final probe = await editor.export();
      final maxBytes = probe!.bytes.length - 1;
      editor.config = ChatImageEditorConfig(
        export: ExportOptions(maxBytes: maxBytes),
      );
      addTearDown(() => editor.config = defaults);

      const warmUp = 1;
      final stats = <ExportStats>[];
      final samples = await sampleAsync(
        (iteration) => timeAsync(() async {
          final result = await editor.export();
          expect(result!.exceedsMaxBytes, isFalse);
          if (iteration >= warmUp) stats.add(result.stats!);
        }),
        warmUp: warmUp,
        iterations: 4,
      );
      final last = stats.last;
      expect(last.encodeAttempts, greaterThan(1));
      report.add(
        BenchmarkResult.fromSamples(
          'export: maxBytes ladder',
          samples,
          notes:
              'maxBytes ${_mb(maxBytes)}: ${last.encodeAttempts} encodes '
              '(quality 90 down to ${last.finalQuality}); ${_phases(stats)}.',
        ),
      );
    });

    test('estimateSize: first call', () async {
      final samples = await sampleAsync(
        (iteration) async {
          // A new edit invalidates the cached render, as editing does.
          editor
            ..startStroke(Offset(0.05 + iteration * 0.01, 0.05))
            ..endStroke();
          return timeAsync(() async {
            expect(await editor.estimateSize(90), isNotNull);
          });
        },
        warmUp: 1,
        iterations: 5,
      );
      report.add(
        BenchmarkResult.fromSamples(
          'estimateSize: first call',
          samples,
          notes:
              'Renders the edits at export size and encodes once; what the '
              'compress tool pays when it opens after an edit.',
        ),
      );
    });

    test('estimateSize: new quality, render cached', () async {
      expect(await editor.estimateSize(90), isNotNull);
      final samples = await sampleAsync(
        (iteration) => timeAsync(() async {
          expect(await editor.estimateSize(85 - iteration), isNotNull);
        }),
        warmUp: 1,
        iterations: 5,
      );
      report.add(
        BenchmarkResult.fromSamples(
          'estimateSize: new quality',
          samples,
          notes:
              'Reuses the cached render and encodes at a quality not '
              'estimated yet; the cost of each new slider position.',
        ),
      );
    });

    test('estimateSize: cached', () async {
      expect(await editor.estimateSize(70), isNotNull);
      final samples = await sampleAsync(
        (_) => timeAsync(() async {
          expect(await editor.estimateSize(70), isNotNull);
        }),
        warmUp: 20,
        iterations: 200,
      );
      report.add(
        BenchmarkResult.fromSamples(
          'estimateSize: cached',
          samples,
          notes: 'A quality already estimated for the same edits.',
        ),
      );
    });
  });
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';

String _ns(List<double> samplesMs, int calls) {
  final mean = samplesMs.reduce((a, b) => a + b) / samplesMs.length;
  return (mean * 1e6 / calls).toStringAsFixed(1);
}

/// Mean time of each export phase from [stats].
String _phases(List<ExportStats> stats) {
  double mean(Duration Function(ExportStats s) phase) {
    final total = stats.fold<int>(0, (sum, s) => sum + phase(s).inMicroseconds);
    return total / stats.length / 1000;
  }

  String ms(double value) => '${value.toStringAsFixed(0)} ms';
  return 'mean decode ${ms(mean((s) => s.decodeTime))}, '
      'render ${ms(mean((s) => s.renderTime))}, '
      'encode ${ms(mean((s) => s.encodeTime))}';
}
