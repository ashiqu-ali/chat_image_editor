/// The tool currently open in the editor.
enum EditorTool {
  /// No tool open: plain preview, pinch-to-zoom enabled.
  none,

  /// Freehand and shape drawing.
  draw,

  /// Text layers.
  text,

  /// Crop frame with rotate and flip controls.
  crop,

  /// Quality slider with a live size estimate.
  compress,
}

/// Shape produced by the draw tool.
enum ShapeType {
  /// Smoothed freehand stroke through every sampled point.
  freehand,

  /// Straight line from the first to the last point.
  line,

  /// Axis-aligned rectangle spanned by the first and last point.
  rectangle,

  /// Ellipse inscribed in the rectangle spanned by the first and last point.
  circle,

  /// Line with an arrowhead at the last point.
  arrow,
}

/// Background drawn behind a text layer.
enum TextBackgroundStyle {
  /// Text only.
  none,

  /// Opaque rounded box in the text color; text switches to a contrasting
  /// color.
  solid,

  /// Semi-transparent rounded box behind the text.
  translucent,
}

/// Encoded format of the exported image.
enum ExportFormat {
  /// JPEG: small files, no transparency.
  jpeg('image/jpeg', 'jpg'),

  /// PNG: lossless, keeps transparency, larger files.
  png('image/png', 'png');

  const ExportFormat(this.mimeType, this.fileExtension);

  /// MIME type of the encoded bytes, e.g. `image/jpeg`.
  final String mimeType;

  /// File extension without the dot, e.g. `jpg`.
  final String fileExtension;
}

/// What the bottom of the editor shows.
enum ChatImageEditorMode {
  /// Caption field plus a send button.
  send,

  /// A single done button, no caption.
  done,
}

/// Progress of decoding the source image.
enum ImageLoadStatus {
  /// Nothing loaded yet.
  idle,

  /// Decoding is in progress.
  loading,

  /// The image is decoded and ready to edit.
  ready,

  /// Decoding failed; see `ChatImageEditorController.loadError`.
  failed,
}
