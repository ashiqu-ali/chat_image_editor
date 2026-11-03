import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Timing summary of one benchmark, in milliseconds.
@immutable
class BenchmarkResult {
  /// Creates a result from already computed values.
  const BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.minMs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.maxMs,
    this.notes = '',
  });

  /// Summarizes [samplesMs], one entry per measured iteration.
  factory BenchmarkResult.fromSamples(
    String name,
    List<double> samplesMs, {
    String notes = '',
  }) {
    if (samplesMs.isEmpty) {
      throw ArgumentError.value(samplesMs, 'samplesMs', 'is empty');
    }
    final sorted = List<double>.of(samplesMs)..sort();
    final mean = sorted.reduce((a, b) => a + b) / sorted.length;
    return BenchmarkResult(
      name: name,
      iterations: sorted.length,
      minMs: sorted.first,
      meanMs: mean,
      p50Ms: percentile(sorted, 0.5),
      p90Ms: percentile(sorted, 0.9),
      maxMs: sorted.last,
      notes: notes,
    );
  }

  /// Benchmark name, unique within a run.
  final String name;

  /// Number of measured iterations (warm-up runs excluded).
  final int iterations;

  /// Fastest iteration.
  final double minMs;

  /// Average iteration.
  final double meanMs;

  /// Median iteration.
  final double p50Ms;

  /// 90th percentile iteration.
  final double p90Ms;

  /// Slowest iteration.
  final double maxMs;

  /// What was measured, in a sentence.
  final String notes;

  /// The JSON object written to `results.json`.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'iterations': iterations,
    'minMs': _round(minMs),
    'meanMs': _round(meanMs),
    'p50Ms': _round(p50Ms),
    'p90Ms': _round(p90Ms),
    'maxMs': _round(maxMs),
    'notes': notes,
  };

  static double _round(double ms) => (ms * 10000).roundToDouble() / 10000;
}

/// The value at fraction [p] (0..1) of [sorted], interpolating linearly
/// between the two nearest samples.
double percentile(List<double> sorted, double p) {
  if (sorted.length == 1) return sorted.single;
  final rank = p * (sorted.length - 1);
  final low = rank.floor();
  final high = rank.ceil();
  return sorted[low] + (sorted[high] - sorted[low]) * (rank - low);
}

/// Milliseconds elapsed on [stopwatch], with sub-microsecond precision.
double elapsedMs(Stopwatch stopwatch) =>
    stopwatch.elapsedTicks * 1000 / stopwatch.frequency;

/// Runs [body] [warmUp] times without measuring, then [iterations] times,
/// and returns the milliseconds each measured run took.
///
/// [body] times itself and returns the milliseconds to record, so per-run
/// setup can stay outside the measurement (see [timeAsync]).
Future<List<double>> sampleAsync(
  Future<double> Function(int iteration) body, {
  required int warmUp,
  required int iterations,
}) async {
  for (var i = 0; i < warmUp; i++) {
    await body(i);
  }
  final samples = <double>[];
  for (var i = 0; i < iterations; i++) {
    samples.add(await body(warmUp + i));
  }
  return samples;
}

/// Synchronous [sampleAsync]: [body] runs inside the measurement.
List<double> sampleSync(
  void Function() body, {
  required int warmUp,
  required int iterations,
}) {
  for (var i = 0; i < warmUp; i++) {
    body();
  }
  final samples = <double>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < iterations; i++) {
    stopwatch
      ..reset()
      ..start();
    body();
    stopwatch.stop();
    samples.add(elapsedMs(stopwatch));
  }
  return samples;
}

/// Milliseconds [action] takes to complete.
Future<double> timeAsync(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return elapsedMs(stopwatch);
}

/// Collects results and writes them as one JSON document.
class BenchmarkReport {
  /// Results in the order they finished.
  final List<BenchmarkResult> results = <BenchmarkResult>[];

  /// Process memory readings, in bytes.
  final Map<String, int> memory = <String, int>{};

  /// Adds [result].
  void add(BenchmarkResult result) => results.add(result);

  /// Records the current resident set size under [key].
  int recordRss(String key) => memory[key] = ProcessInfo.currentRss;

  /// The whole report as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'flutterVersion': _flutterVersion(),
    'dartVersion': Platform.version.split(' ').first,
    'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'buildMode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'benchmarks': <Map<String, Object?>>[
      for (final result in results) result.toJson(),
    ],
    'memory': memory,
  };

  /// Writes the report to [file], creating its folder.
  Future<void> write(File file) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(toJson())}\n');
  }

  /// The Flutter version from the tool's defines, falling back to the SDK's
  /// version file.
  static String _flutterVersion() {
    const defined = FlutterVersion.version;
    if (defined != null && defined.isNotEmpty) return defined;
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      try {
        final info = File('$root/bin/cache/flutter.version.json');
        final json = jsonDecode(info.readAsStringSync());
        if (json is Map<String, Object?>) {
          final version = json['frameworkVersion'] ?? json['flutterVersion'];
          if (version is String) return version;
        }
      } on Object {
        // Fall through to "unknown".
      }
    }
    return 'unknown';
  }
}
