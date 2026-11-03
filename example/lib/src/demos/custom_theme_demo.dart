import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

/// Overrides colors, swaps icons and replaces the send button.
Future<ChatImageEditorResult?> openCustomThemeDemo(
  BuildContext context,
  Uint8List image,
) {
  return ChatImageEditor.open(
    context,
    image,
    theme: _duskTheme,
    icons: _roundedIcons,
    builders: const ChatImageEditorBuilders(sendButton: _buildPillSendButton),
  );
}

/// Any field left out keeps inheriting from the app theme.
const ChatImageEditorThemeData _duskTheme = ChatImageEditorThemeData(
  primaryColor: Color(0xFFFFB74D),
  onPrimaryColor: Color(0xFF2B1700),
  backgroundColor: Color(0xFF15121F),
  toolbarBackgroundColor: Color(0x73000000),
  activeToolColor: Color(0xFFFFD180),
  cropFrameColor: Color(0xFFFFB74D),
  cropHandleColor: Color(0xFFFFE0B2),
  sliderInactiveColor: Color(0x40FFE0B2),
  captionFillColor: Color(0xFF2A2538),
  captionHintColor: Color(0x99FFE0B2),
  sheetBackgroundColor: Color(0xFF211C30),
  defaultTextColor: Color(0xFFFFE0B2),
  palette: <Color>[
    Color(0xFFFFE0B2),
    Color(0xFFFFB74D),
    Color(0xFFFF7043),
    Color(0xFFEC407A),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
    Color(0xFF26C6DA),
    Color(0xFF15121F),
  ],
  textLayerStyle: TextStyle(
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    height: 1.15,
    shadows: <Shadow>[Shadow(blurRadius: 6, color: Color(0x80000000))],
  ),
  captionBorderRadius: BorderRadius.all(Radius.circular(14)),
  iconSize: 26,
);

/// Icons accept any widget; plain Material icons pick up the themed color.
const ChatImageEditorIcons _roundedIcons = ChatImageEditorIcons(
  close: Icon(Icons.arrow_back_rounded),
  undo: Icon(Icons.undo_rounded),
  redo: Icon(Icons.redo_rounded),
  draw: Icon(Icons.brush_rounded),
  text: Icon(Icons.text_fields_rounded),
  crop: Icon(Icons.crop_rounded),
  compress: Icon(Icons.tune_rounded),
  delete: Icon(Icons.delete_forever_rounded),
  send: Icon(Icons.arrow_upward_rounded),
);

Widget _buildPillSendButton(BuildContext context, SendButtonDetails details) {
  return _PillSendButton(details: details);
}

/// A pill-shaped send button that reads its colors, icon and label from
/// the editor's scope, so it stays in sync with the theme above.
class _PillSendButton extends StatelessWidget {
  const _PillSendButton({required this.details});

  final SendButtonDetails details;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final active = details.enabled && !details.busy;
    final foreground = theme.sendButtonForegroundColor;

    return Semantics(
      button: true,
      enabled: active,
      label: scope.strings.send,
      child: Material(
        color: active ? theme.sendButtonColor : theme.sendButtonDisabledColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: details.onPressed,
          onLongPress: details.onLongPress,
          child: SizedBox(
            height: theme.sendButtonSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Text(
                      scope.strings.send,
                      style: theme.labelStyle.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (details.busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    IconTheme.merge(
                      data: IconThemeData(color: foreground, size: 20),
                      child: scope.icons.sendIcon,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
