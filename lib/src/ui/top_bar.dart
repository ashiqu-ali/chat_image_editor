import 'package:flutter/material.dart';

import '../models/editor_enums.dart';
import '../theme/chat_image_editor_icons.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import 'controller_selector.dart';
import 'editor_host.dart';
import 'editor_icon_button.dart';
import 'editor_layout.dart';
import 'editor_pill_button.dart';

/// The default top bar: close, undo/redo, then the configured tools.
///
/// While drawing it morphs: close becomes a "Done" pill, and the tools fold
/// into undo plus a swatch of the pen color.
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
    final strings = scope.strings;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: EditorLayout.topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child:
              ControllerSelector<
                ({EditorTool tool, bool undo, bool redo, Color color})
              >(
                selector: (c) => (
                  tool: c.activeTool,
                  undo: c.canUndo,
                  redo: c.canRedo,
                  color: c.drawColor,
                ),
                builder: (context, state, _) {
                  final drawing = state.tool == EditorTool.draw;
                  final undo = EditorIconButton(
                    icon: scope.icons.undoIcon,
                    tooltip: strings.undo,
                    onPressed: state.undo ? controller.undo : null,
                  );

                  final Widget leading = drawing
                      ? EditorPillButton(
                          key: const ValueKey<String>('draw-done'),
                          label: strings.done,
                          onPressed: controller.closeTool,
                        )
                      : EditorIconButton(
                          key: const ValueKey<String>('close'),
                          icon: scope.icons.closeIcon,
                          tooltip: strings.close,
                          onPressed: () => host.close(context),
                        );

                  final Widget trailing = drawing
                      ? Row(
                          key: const ValueKey<String>('draw-actions'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (config.showUndoRedo) undo,
                            _PenSwatch(
                              color: state.color,
                              onPressed: controller.closeTool,
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          key: const ValueKey<String>('tools'),
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (config.showUndoRedo) ...<Widget>[
                                undo,
                                EditorIconButton(
                                  icon: scope.icons.redoIcon,
                                  tooltip: strings.redo,
                                  onPressed: state.redo
                                      ? controller.redo
                                      : null,
                                ),
                              ],
                              for (final tool in config.tools)
                                if (tool != EditorTool.none)
                                  EditorIconButton(
                                    icon: iconFor(tool, scope.icons)!,
                                    tooltip: labelFor(tool, strings),
                                    active: state.tool == tool,
                                    onPressed: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      controller.selectTool(tool);
                                    },
                                  ),
                            ],
                          ),
                        );

                  return Row(
                    children: <Widget>[
                      _Morph(
                        alignment: AlignmentDirectional.centerStart,
                        slideFrom: const Offset(-0.5, 0),
                        child: leading,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _Morph(
                            alignment: AlignmentDirectional.centerEnd,
                            slideFrom: const Offset(0.35, 0),
                            child: trailing,
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

/// The pen's current color with the draw icon on it. Tapping it ends
/// drawing, like tapping the draw tool again.
class _PenSwatch extends StatelessWidget {
  const _PenSwatch({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    return Tooltip(
      message: scope.strings.draw,
      child: Semantics(
        button: true,
        selected: true,
        child: InkResponse(
          onTap: onPressed,
          radius: EditorIconButton.hitSize / 2,
          child: SizedBox.square(
            dimension: EditorIconButton.hitSize,
            child: Center(
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                width: EditorIconButton.backdropSize,
                height: EditorIconButton.backdropSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.foregroundColor, width: 1.5),
                  // Keeps a white swatch readable on a bright photo.
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x66000000), blurRadius: 4),
                  ],
                ),
                alignment: Alignment.center,
                child: IconTheme.merge(
                  data: IconThemeData(color: onColor, size: theme.iconSize - 4),
                  child: scope.icons.drawIcon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cross-fades between two groups of top bar buttons: the outgoing group
/// shrinks into [alignment] while the incoming one grows out of it, sliding
/// in from [slideFrom] (mirrored in right-to-left layouts).
///
/// The outgoing group can't be tapped or reached by screen readers while it
/// fades, and it keeps its state until it's gone.
class _Morph extends StatelessWidget {
  const _Morph({
    required this.alignment,
    required this.slideFrom,
    required this.child,
  });

  final AlignmentDirectional alignment;
  final Offset slideFrom;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final direction = Directionality.of(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
            alignment: alignment.resolve(direction),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: slideFrom,
                end: Offset.zero,
              ).animate(slide),
              textDirection: direction,
              child: child,
            ),
          ),
        );
      },
      layoutBuilder: (current, previous) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: alignment,
          children: <Widget>[
            for (final child in previous) _interactive(child, enabled: false),
            if (current != null) _interactive(current, enabled: true),
          ],
        );
      },
      child: child,
    );
  }

  /// Wraps a group so it ignores taps and screen readers unless [enabled].
  /// The wrapper takes the group's key, so a group that starts leaving keeps
  /// its element (and its ink, scroll position and tooltips) as it fades.
  static Widget _interactive(Widget child, {required bool enabled}) {
    return IgnorePointer(
      key: child.key,
      ignoring: !enabled,
      child: ExcludeSemantics(excluding: !enabled, child: child),
    );
  }
}
