import 'package:flutter/widgets.dart';

import '../models/editor_enums.dart';
import '../theme/chat_image_editor_icons.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import 'controller_selector.dart';
import 'editor_host.dart';
import 'editor_icon_button.dart';
import 'editor_layout.dart';

/// The default top bar: close, undo/redo, then the configured tools.
class EditorTopBar extends StatelessWidget {
  /// Creates the top bar.
  const EditorTopBar({super.key});

  /// The icon for [tool], or `null` for [EditorTool.none].
  static Widget? iconFor(EditorTool tool, ChatImageEditorIcons icons) {
    switch (tool) {
      case EditorTool.draw:
        return icons.drawIcon;
      case EditorTool.text:
        return icons.textIcon;
      case EditorTool.crop:
        return icons.cropIcon;
      case EditorTool.compress:
        return icons.compressIcon;
      case EditorTool.none:
        return null;
    }
  }

  /// The tooltip for [tool].
  static String labelFor(EditorTool tool, ChatImageEditorStrings strings) {
    switch (tool) {
      case EditorTool.draw:
        return strings.draw;
      case EditorTool.text:
        return strings.text;
      case EditorTool.crop:
        return strings.crop;
      case EditorTool.compress:
        return strings.compress;
      case EditorTool.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final controller = scope.controller;
    final config = scope.config;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: EditorLayout.topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ControllerSelector<({EditorTool tool, bool undo, bool redo})>(
            selector: (c) =>
                (tool: c.activeTool, undo: c.canUndo, redo: c.canRedo),
            builder: (context, state, _) {
              return Row(
                children: <Widget>[
                  EditorIconButton(
                    icon: scope.icons.closeIcon,
                    tooltip: scope.strings.close,
                    onPressed: () => host.close(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (config.showUndoRedo) ...<Widget>[
                              EditorIconButton(
                                icon: scope.icons.undoIcon,
                                tooltip: scope.strings.undo,
                                onPressed: state.undo ? controller.undo : null,
                              ),
                              EditorIconButton(
                                icon: scope.icons.redoIcon,
                                tooltip: scope.strings.redo,
                                onPressed: state.redo ? controller.redo : null,
                              ),
                            ],
                            for (final tool in config.tools)
                              if (tool != EditorTool.none)
                                EditorIconButton(
                                  icon: iconFor(tool, scope.icons)!,
                                  tooltip: labelFor(tool, scope.strings),
                                  active: state.tool == tool,
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    controller.selectTool(tool);
                                  },
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
