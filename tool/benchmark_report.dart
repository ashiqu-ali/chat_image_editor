// Prints the benchmark results as Markdown.
//
//   fvm flutter test benchmark
//   fvm dart run tool/benchmark_report.dart build/benchmark/results.json
//
// Pure Dart (no Flutter imports), so it runs with the plain Dart VM.
import 'dart:convert';
import 'dart:io';

/// Exit code for a wrong command line (EX_USAGE).
const int usageError = 64;

/// Exit code for a results file that isn't shaped as expected (EX_DATAERR).
const int dataError = 65;

/// Exit code for a missing results file (EX_NOINPUT).
const int missingInput = 66;

Future<void> main(List<String> args) async {
  if (args.length != 1 || args.first == '-h' || args.first == '--help') {
    stderr
      ..writeln('Prints benchmark results as a Markdown table.')
      ..writeln()
      ..writeln('Usage: dart run tool/benchmark_report.dart <results.json>');
    exitCode = args.length == 1 ? 0 : usageError;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln(
      'No results at ${file.path}. Run `fvm flutter test benchmark` first.',
    );
    exitCode = missingInput;
    return;
  }

  final String markdown;
  try {
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, Object?>) {
      throw const FormatException('The top level is not a JSON object.');
    }
    markdown = renderReport(json);
  } on FormatException catch (error) {
    stderr.writeln('Could not read ${file.path}: ${error.message}');
    exitCode = dataError;
    return;
  }
  stdout.write(markdown);
}

/// Renders the decoded `results.json` as Markdown.
String renderReport(Map<String, Object?> results) {
  final out = StringBuffer()
    ..writeln('## chat_image_editor benchmarks')
    ..writeln();

  final details = <String>[
    'Flutter ${results['flutterVersion'] ?? 'unknown'}',
    'Dart ${results['dartVersion'] ?? 'unknown'}',
    if (results['os'] case final String os) os,
    if (results['buildMode'] case final String mode) '$mode build',
    if (results['createdAt'] case final String createdAt) createdAt,
  ];
  out
    ..writeln(details.join(' · '))
    ..writeln();

  final benchmarks = results['benchmarks'];
  if (benchmarks is! List<Object?>) {
    throw const FormatException('"benchmarks" is not a list.');
  }
  out
    ..writeln(
      '| Benchmark | Iterations | Mean (ms) | p50 (ms) | p90 (ms) '
      '| Min (ms) | Max (ms) |',
    )
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: |');
  final notes = <String>[];
  for (final entry in benchmarks) {
    if (entry is! Map<String, Object?>) {
      throw const FormatException('A benchmark entry is not an object.');
    }
    final name = _cell(entry['name'] ?? '?');
    final cells = <String>[
      name,
      '${entry['iterations'] ?? '?'}',
      _ms(entry['meanMs']),
      _ms(entry['p50Ms']),
      _ms(entry['p90Ms']),
      _ms(entry['minMs']),
      _ms(entry['maxMs']),
    ];
    out.writeln('| ${cells.join(' | ')} |');
    final note = entry['notes'];
    if (note is String && note.isNotEmpty) notes.add('- **$name**: $note');
  }

  final memory = results['memory'];
  if (memory is Map<String, Object?> && memory.isNotEmpty) {
    out
      ..writeln()
      ..writeln('### Memory')
      ..writeln()
      ..writeln('| Measurement | Value |')
      ..writeln('| --- | ---: |');
    for (final MapEntry(:key, :value) in memory.entries) {
      out.writeln('| ${_cell(_memoryLabel(key))} | ${_memory(key, value)} |');
    }
  }

  if (notes.isNotEmpty) {
    out
      ..writeln()
      ..writeln('### Notes')
      ..writeln();
    notes.forEach(out.writeln);
  }
  return out.toString();
}

/// Readable names for the memory keys the benchmarks write.
const Map<String, String> _memoryLabels = <String, String>{
  'rssBeforeExportBytes': 'RSS before the export benchmarks',
  'rssAfterExportBytes': 'RSS after the export benchmarks',
  'rssDeltaExportBytes': 'RSS change across the export benchmarks',
  'maxRssBytes': 'Peak RSS of the whole run',
};

String _memoryLabel(String key) => _memoryLabels[key] ?? key;

String _memory(String key, Object? value) {
  if (value is! num) return _cell(value ?? '');
  if (!key.endsWith('Bytes')) return '$value';
  final mb = value / (1024 * 1024);
  final sign = key.contains('Delta') && mb > 0 ? '+' : '';
  return '$sign${mb.toStringAsFixed(1)} MB';
}

/// Milliseconds with enough digits to tell fast entries apart.
String _ms(Object? value) {
  if (value is! num) return '?';
  final abs = value.abs();
  final digits = abs >= 100
      ? 1
      : abs >= 1
      ? 2
      : abs >= 0.01
      ? 3
      : 4;
  return value.toStringAsFixed(digits);
}

/// [value] as text that can't break a Markdown table row.
String _cell(Object value) =>
    '$value'.replaceAll('|', r'\|').replaceAll('\n', ' ');
