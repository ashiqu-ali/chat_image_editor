import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import '../edit_summary.dart';

/// Pushes [ControllerDemoScreen] and completes with its result.
Future<ChatImageEditorResult?> openControllerDemo(
  BuildContext context,
  Uint8List image,
) {
  return Navigator.of(context).push<ChatImageEditorResult>(
    MaterialPageRoute<ChatImageEditorResult>(
      builder: (context) => ControllerDemoScreen(image: image),
    ),
  );
}

/// Embeds [ChatImageEditor] in a screen and drives it from outside through
/// an external [ChatImageEditorController].
///
/// The panel below the editor listens to the controller for live state
/// (edit counts, undo/redo availability) and calls its actions directly.
/// Everything it does is also undoable from the editor's own top bar.
class ControllerDemoScreen extends StatefulWidget {
  /// Creates the screen for [image].
  const ControllerDemoScreen({super.key, required this.image});

  /// Encoded source image.
  final Uint8List image;

  @override
  State<ControllerDemoScreen> createState() => _ControllerDemoScreenState();
}

class _ControllerDemoScreenState extends State<ControllerDemoScreen> {
  static const ChatImageEditorConfig _config = ChatImageEditorConfig(
    mode: ChatImageEditorMode.done,
  );

  // Created here and handed to the editor, so this screen owns it.
  late final ChatImageEditorController _controller = ChatImageEditorController(
    config: _config,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ends whatever tool is open so a scripted edit starts from a clean
  /// state. An open crop session is kept rather than thrown away.
  void _closeOpenTool() {
    switch (_controller.activeTool) {
      case EditorTool.none:
        return;
      case EditorTool.crop:
        _controller.confirmCrop();
      case EditorTool.draw:
      case EditorTool.text:
      case EditorTool.compress:
        _controller.closeTool();
    }
  }

  /// Runs a rotate or flip inside its own crop session, which records it
  /// as one undoable step.
  void _transform(VoidCallback action) {
    _closeOpenTool();
    _controller.selectTool(EditorTool.crop);
    action();
    _controller.confirmCrop();
  }

  void _drawArrow() {
    _closeOpenTool();
    final controller = _controller;
    final previousShape = controller.shapeType;
    final previousWidth = controller.strokeWidth;
    controller
      ..selectTool(EditorTool.draw)
      ..setShapeType(ShapeType.arrow)
      ..setStrokeWidth(controller.config.maxStrokeWidth / 2)
      // Points are normalized over the visible image: (0, 0) is its
      // top-left corner and (1, 1) its bottom-right.
      ..startStroke(const Offset(0.2, 0.8))
      ..updateStroke(const Offset(0.8, 0.3))
      ..endStroke()
      ..setShapeType(previousShape)
      ..setStrokeWidth(previousWidth)
      ..closeTool();
  }

  void _addText() {
    _closeOpenTool();
    _controller
      ..addText(viewPosition: const Offset(0.5, 0.18))
      ..updateEditingText('Hello from code')
      ..finishTextEditing();
    _closeOpenTool();
  }

  Future<void> _exportFromCode() async {
    _closeOpenTool();
    final result = await _controller.export(caption: 'Exported from code');
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The editor handles the keyboard itself.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: <Widget>[
          Expanded(
            // The panel below owns the bottom safe area.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: ChatImageEditor(
                image: widget.image,
                controller: _controller,
                config: _config,
                onComplete: (result) => Navigator.of(context).pop(result),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    final ready = controller.loadStatus == ImageLoadStatus.ready;
    final idle = ready && !controller.isExporting;

    VoidCallback? enabledIf(bool enabled, VoidCallback action) {
      return enabled ? action : null;
    }

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _status(controller),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  _PanelChip(
                    icon: Icons.rotate_left,
                    label: 'Rotate left',
                    onPressed: enabledIf(
                      idle,
                      () => _transform(controller.rotateLeft),
                    ),
                  ),
                  _PanelChip(
                    icon: Icons.rotate_right,
                    label: 'Rotate right',
                    onPressed: enabledIf(
                      idle,
                      () => _transform(controller.rotateRight),
                    ),
                  ),
                  _PanelChip(
                    icon: Icons.flip,
                    label: 'Flip',
                    onPressed: enabledIf(
                      idle,
                      () => _transform(controller.flipHorizontal),
                    ),
                  ),
                  _PanelChip(
                    icon: Icons.north_east,
                    label: 'Arrow',
                    onPressed: enabledIf(idle, _drawArrow),
                  ),
                  _PanelChip(
                    icon: Icons.title,
                    label: 'Add text',
                    onPressed: enabledIf(idle, _addText),
                  ),
                  _PanelChip(
                    icon: Icons.undo,
                    label: 'Undo',
                    onPressed: enabledIf(
                      idle && controller.canUndo,
                      controller.undo,
                    ),
                  ),
                  _PanelChip(
                    icon: Icons.redo,
                    label: 'Redo',
                    onPressed: enabledIf(
                      idle && controller.canRedo,
                      controller.redo,
                    ),
                  ),
                  _PanelChip(
                    icon: Icons.layers_clear_outlined,
                    label: 'Clear',
                    onPressed: enabledIf(
                      idle && controller.value.hasChanges,
                      controller.clearEdits,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: enabledIf(idle, _exportFromCode),
                icon: controller.isExporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: const Text('Export from code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _status(ChatImageEditorController controller) {
    switch (controller.loadStatus) {
      case ImageLoadStatus.idle:
      case ImageLoadStatus.loading:
        return 'Loading the image…';
      case ImageLoadStatus.failed:
        return 'The image could not be loaded.';
      case ImageLoadStatus.ready:
        if (controller.isExporting) return 'Exporting…';
        final tool = controller.activeTool;
        final edits = describeEdits(controller.value);
        return tool == EditorTool.none ? edits : '$edits · ${tool.name} open';
    }
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
