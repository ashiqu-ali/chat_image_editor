import 'package:flutter/material.dart';

import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'caption_bar.dart';
import 'compress_sheet.dart';
import 'controller_selector.dart';
import 'crop_controls.dart';
import 'crop_overlay.dart';
import 'delete_target.dart';
import 'draw_controls.dart';
import 'editor_canvas.dart';
import 'editor_host.dart';
import 'editor_icon_button.dart';
import 'text_entry_overlay.dart';
import 'top_bar.dart';

typedef _ViewState = ({
  ImageLoadStatus status,
  EditorTool tool,
  String? editingId,
  bool gesture,
  bool overDelete,
  bool drawing,
  bool exporting,
});

/// The editor's screen: loading and error states, then the canvas with the
/// chrome for the open tool layered on top.
class EditorView extends StatelessWidget {
  /// Creates the view.
  const EditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: DefaultTextStyle.merge(
        style: theme.labelStyle,
        child: IconTheme.merge(
          data: IconThemeData(
            color: theme.foregroundColor,
            size: theme.iconSize,
          ),
          child: ControllerSelector<_ViewState>(
            selector: (c) => (
              status: c.loadStatus,
              tool: c.activeTool,
              editingId: c.editingTextId,
              gesture: c.activeTextId != null,
              overDelete: c.isOverDeleteTarget,
              drawing: c.draftStroke != null,
              exporting: c.isExporting,
            ),
            builder: (context, state, _) {
              switch (state.status) {
                case ImageLoadStatus.idle:
                case ImageLoadStatus.loading:
                  return const _StatusView(failed: false);
                case ImageLoadStatus.failed:
                  return const _StatusView(failed: true);
                case ImageLoadStatus.ready:
                  return _ReadyView(state: state);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state});

  final _ViewState state;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final tool = state.tool;
    final editing = state.editingId != null;
    final safe = MediaQuery.viewPaddingOf(context);

    final showTopBar = tool != EditorTool.crop && !editing;
    final showBottomBar =
        (tool == EditorTool.none || tool == EditorTool.text) && !editing;
    final hideChrome = state.gesture || state.drawing;

    final topBar = scope.builders.topBar?.call(context, scope.controller);

    return AbsorbPointer(
      absorbing: state.exporting,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const EditorCanvas(),
          if (tool == EditorTool.crop) const CropOverlay(),
          if (tool == EditorTool.crop) const CropControls(),
          if (tool == EditorTool.draw && !editing)
            _Fade(visible: !state.drawing, child: const DrawControls()),
          if (showTopBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _Fade(
                visible: !hideChrome,
                child: topBar ?? const EditorTopBar(),
              ),
            ),
          if (showBottomBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Fade(
                visible: !state.gesture,
                child: const EditorBottomBar(),
              ),
            ),
          if (state.gesture)
            Positioned(
              left: 0,
              right: 0,
              bottom: safe.bottom + 32,
              child: Center(
                child: DeleteTarget(
                  key: host.deleteTargetKey,
                  active: state.overDelete,
                ),
              ),
            ),
          if (editing)
            Positioned.fill(
              child: TextEntryOverlay(key: ValueKey<String?>(state.editingId)),
            ),
          if (tool == EditorTool.compress)
            const Positioned.fill(child: CompressSheet()),
        ],
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final theme = scope.theme;
    final controller = scope.controller;

    final Widget body;
    if (failed) {
      final error = controller.loadError ?? scope.strings.loadFailed;
      body =
          scope.builders.error?.call(context, error) ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                scope.strings.loadFailed,
                style: theme.labelStyle,
                textAlign: TextAlign.center,
              ),
            ),
          );
    } else {
      body =
          scope.builders.loading?.call(context) ??
          Center(
            child: CircularProgressIndicator(
              color: theme.loadingIndicatorColor,
            ),
          );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        body,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: EditorIconButton(
                icon: scope.icons.closeIcon,
                tooltip: scope.strings.close,
                onPressed: () => host.close(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
