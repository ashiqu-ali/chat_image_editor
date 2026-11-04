import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

/// Every label, tooltip and message in Spanish, plus a caption header.
Future<ChatImageEditorResult?> openLocalizedDemo(
  BuildContext context,
  Uint8List image,
) {
  return ChatImageEditor.open(
    context,
    image,
    strings: spanishEditorStrings,
    captionField: const CaptionFieldConfig(header: _RecipientHeader()),
  );
}

/// A Spanish translation of [ChatImageEditorStrings].
const ChatImageEditorStrings spanishEditorStrings = ChatImageEditorStrings(
  captionHint: 'Añade un comentario…',
  close: 'Cerrar',
  undo: 'Deshacer',
  redo: 'Rehacer',
  draw: 'Dibujar',
  text: 'Texto',
  crop: 'Recortar y girar',
  compress: 'Calidad de la imagen',
  rotateLeft: 'Girar a la izquierda',
  rotateRight: 'Girar a la derecha',
  flipHorizontal: 'Voltear en horizontal',
  flipVertical: 'Voltear en vertical',
  resetCrop: 'Restablecer',
  freeAspectRatio: 'Libre',
  confirm: 'Aceptar',
  cancel: 'Cancelar',
  send: 'Enviar',
  done: 'Listo',
  delete: 'Eliminar',
  textBackground: 'Fondo del texto',
  strokeWidth: 'Grosor del pincel',
  freehand: 'Lápiz',
  line: 'Línea',
  rectangle: 'Rectángulo',
  circle: 'Círculo',
  arrow: 'Flecha',
  qualityLabel: 'Calidad',
  originalSizeLabel: 'Original',
  estimatedSizeLabel: 'Tamaño estimado',
  estimatingSize: 'Calculando…',
  discardTitle: '¿Descartar los cambios?',
  discardMessage: 'Se perderán las ediciones de esta imagen.',
  discardConfirm: 'Descartar',
  keepEditing: 'Seguir editando',
  loadFailed: 'No se pudo abrir esta imagen.',
  exportFailed: 'No se pudo preparar la imagen. Inténtalo de nuevo.',
  color: 'Color',
  apply: 'Aplicar',
  formatBytes: formatBytesWithDecimalComma,
  colorLabel: spanishColorLabel,
  formatQuality: spanishFormatQuality,
);

/// Names the palette color nearest the color slider for screen readers,
/// e.g. `Color 3 de 10`.
String spanishColorLabel(Color color, int index, int count) {
  return 'Color ${index + 1} de $count';
}

/// Names the quality tier with the same bounds as the English default,
/// e.g. `Alta · 90`.
String spanishFormatQuality(int quality) {
  final String tier;
  if (quality <= 40) {
    tier = 'Baja';
  } else if (quality <= 75) {
    tier = 'Media';
  } else {
    tier = 'Alta';
  }
  return '$tier · $quality';
}

/// Formats a byte count with a decimal comma, e.g. `1,4 MB`.
String formatBytesWithDecimalComma(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${_oneDecimal(kilobytes)} KB';
  return '${_oneDecimal(kilobytes / 1024)} MB';
}

String _oneDecimal(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Shown above the caption field. It reads the editor's label style from
/// the scope so it matches the rest of the editor.
class _RecipientHeader extends StatelessWidget {
  const _RecipientHeader();

  @override
  Widget build(BuildContext context) {
    final style =
        ChatImageEditorScope.maybeOf(context)?.theme.labelStyle ??
        Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text('Para: Equipo de diseño', style: style),
    );
  }
}
