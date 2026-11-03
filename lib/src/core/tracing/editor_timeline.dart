import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Timeline spans that show in the Performance view of Flutter DevTools.
///
/// Every span name starts with `chat_image_editor.`. Async work uses
/// `TimelineTask` spans and synchronous work uses `Timeline.timeSync`.
///
/// Release builds have no timeline, so there [enabled] is `false`: [task]
/// returns `null`, call sites skip their spans with `?.`, and [timeSync]
/// just runs its body. Nothing is recorded or allocated for tracing there.
///
/// Internal: not exported from the package.
abstract final class EditorTimeline {
  /// Whether spans are emitted. `false` in release builds.
  static const bool enabled = !kReleaseMode;

  /// Decoding the source for editing: `ChatImageEditorController.load`.
  static const String load = 'chat_image_editor.load';

  /// One decode of encoded bytes into an engine image.
  static const String decode = 'chat_image_editor.decode';

  /// A whole export, from source bytes to the encoded result.
  static const String export = 'chat_image_editor.export';

  /// Decoding, painting and reading back the export pixels.
  static const String render = 'chat_image_editor.render';

  /// One `CompositionRenderer.paint` call: every preview frame and the
  /// export picture.
  static const String paint = 'chat_image_editor.paint';

  /// Turning the recorded export picture into raw RGBA pixels.
  static const String rasterize = 'chat_image_editor.rasterize';

  /// One `ImageEncoder.encode` call made by the exporter.
  static const String encode = 'chat_image_editor.encode';

  /// The pixel work inside `DartImageEncoder`, on its background isolate.
  static const String encodePixels = 'chat_image_editor.encode_pixels';

  /// Stepping JPEG quality down until the file fits `maxBytes`.
  static const String fitMaxBytes = 'chat_image_editor.fit_max_bytes';

  /// One size estimate for the compress tool that wasn't cached yet.
  static const String estimateSize = 'chat_image_editor.estimate_size';

  /// A new async task, linked to [parent] when given, or `null` in release
  /// builds. Start and finish it with `?.` so arguments are only built when
  /// spans are enabled:
  ///
  /// ```dart
  /// final task = EditorTimeline.task()
  ///   ?..start(EditorTimeline.export, arguments: {'bytes': n});
  /// try { ... } finally { task?.finish(); }
  /// ```
  @pragma('vm:prefer-inline')
  static developer.TimelineTask? task({developer.TimelineTask? parent}) {
    if (!enabled) return null;
    return developer.TimelineTask(parent: parent);
  }

  /// Runs [body] inside the synchronous span [name]. [arguments] is only
  /// called when spans are enabled.
  @pragma('vm:prefer-inline')
  static T timeSync<T>(
    String name,
    T Function() body, {
    Map<String, Object?> Function()? arguments,
  }) {
    if (!enabled) return body();
    return developer.Timeline.timeSync<T>(
      name,
      body,
      arguments: arguments?.call(),
    );
  }
}
