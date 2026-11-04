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
    final hideChrome = state.gesture || state.drawing;

    final showCaption =
        (tool == EditorTool.none || tool == EditorTool.text) && !editing;
    final showDrawToolbar = tool == EditorTool.draw && !editing;

    final topBar = scope.builders.topBar?.call(context, scope.controller);

    return AbsorbPointer(
      absorbing: state.exporting,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const EditorCanvas(),
          if (tool == EditorTool.crop) const CropOverlay(),
          if (tool == EditorTool.crop) const CropControls(),
          if (showDrawToolbar)
            _Fade(visible: !state.drawing, child: const DrawColorPicker()),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Fade(
              visible: !hideChrome,
              child: _BottomChrome(
                showCaption: showCaption,
                showDrawToolbar: showDrawToolbar,
              ),
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

/// The bottom controls over a scrim that fades into the photo: the caption
/// bar, or the draw tool's controls, each sliding and fading in and out.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.showCaption,
    required this.showDrawToolbar,
  });

  final bool showCaption;
  final bool showDrawToolbar;

  static const Duration duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    final time = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[theme.scrimColor, theme.scrimColor.withAlpha(0)],
        ),
      ),
      child: AnimatedSize(
        duration: time,
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            // The caption bar stays mounted while a tool is open, so its
            // field, focus and form keep their state and are never built
            // twice during a transition.
            _SlideFade(
              visible: showCaption,
              duration: time,
              child: const EditorBottomBar(),
            ),
            AnimatedSwitcher(
              duration: time,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  for (final child in previous) IgnorePointer(child: child),
                  ?current,
                ],
              ),
              child: showDrawToolbar
                  ? const DrawToolbar(key: ValueKey<String>('draw'))
                  : const SizedBox.shrink(key: ValueKey<String>('none')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides [child] up into place and fades it in when [visible], and back out
/// when not. Once hidden it goes offstage: it takes no space, can't be
/// focused and isn't seen by screen readers, but keeps its state.
class _SlideFade extends StatefulWidget {
  const _SlideFade({
    required this.visible,
    required this.duration,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Widget child;

  @override
  State<_SlideFade> createState() => _SlideFadeState();
}

class _SlideFadeState extends State<_SlideFade> {
  late bool _offstage = !widget.visible;

  @override
  void didUpdateWidget(_SlideFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _offstage = false;
    } else if (widget.duration == Duration.zero) {
      _offstage = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visible;
    return Offstage(
      offstage: _offstage,
      child: ExcludeFocus(
        excluding: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 0.3),
            duration: widget.duration,
            curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: widget.duration,
              onEnd: () {
                if (!widget.visible && mounted) {
                  setState(() => _offstage = true);
                }
              },
              child: widget.child,
            ),
          ),
        ),
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
