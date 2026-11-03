import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/chat_image_editor_controller.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'controller_selector.dart';
import 'editor_icon_button.dart';
import 'editor_slider.dart';

/// The compress tool: a bottom sheet with a quality slider, the original
/// file size and a debounced size estimate.
///
/// Tapping outside the sheet or its done button commits the quality and
/// closes the tool.
class CompressSheet extends StatefulWidget {
  /// Creates the sheet.
  const CompressSheet({super.key});

  /// Delay between the last slider move and the size estimate.
  static const Duration estimateDelay = Duration(milliseconds: 300);

  @override
  State<CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<CompressSheet> {
  Timer? _debounce;
  int _request = 0;
  int? _estimate;
  bool _estimating = false;
  ChatImageEditorController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ChatImageEditorScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller = controller;
      _scheduleEstimate(controller.quality);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request++;
    super.dispose();
  }

  void _scheduleEstimate(int quality) {
    _debounce?.cancel();
    _request++;
    _estimating = true;
    _debounce = Timer(CompressSheet.estimateDelay, () {
      unawaited(_runEstimate(quality));
    });
  }

  Future<void> _runEstimate(int quality) async {
    final controller = _controller;
    if (controller == null) return;
    final request = ++_request;
    int? size;
    try {
      size = await controller.estimateSize(quality);
    } catch (_) {
      size = null;
    }
    if (!mounted || request != _request) return;
    setState(() {
      _estimate = size;
      _estimating = false;
    });
  }

  void _handleChanged(double value) {
    final controller = _controller;
    if (controller == null) return;
    final quality = value.round();
    if (quality == controller.quality) return;
    controller.setQuality(quality);
    setState(() => _scheduleEstimate(quality));
  }

  void _close() {
    final controller = _controller;
    if (controller == null) return;
    controller.commitQuality();
    if (controller.activeTool == EditorTool.compress) controller.closeTool();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final strings = scope.strings;
    final controller = scope.controller;
    final sourceBytes = controller.sourceBytes;
    final estimate = _estimate;

    final String estimateText;
    if (_estimating) {
      estimateText = strings.estimatingSize;
    } else if (estimate != null) {
      estimateText = strings.formatBytes(estimate);
    } else {
      estimateText = '';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.sheetBodyStyle)),
            Text(value, style: theme.sheetBodyStyle),
          ],
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: theme.sheetBackgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
                child: IconTheme.merge(
                  data: IconThemeData(color: theme.sheetForegroundColor),
                  child: ControllerSelector<int>(
                    selector: (c) => c.quality,
                    builder: (context, quality, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  strings.compress,
                                  style: theme.sheetTitleStyle,
                                ),
                              ),
                              EditorIconButton(
                                icon: scope.icons.confirmIcon,
                                tooltip: strings.done,
                                active: true,
                                onPressed: _close,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                row(strings.qualityLabel, '$quality'),
                                EditorSlider(
                                  value: quality.toDouble(),
                                  min: 1,
                                  max: 100,
                                  divisions: 99,
                                  semanticsLabel: strings.qualityLabel,
                                  onChanged: _handleChanged,
                                ),
                                if (sourceBytes != null)
                                  row(
                                    strings.originalSizeLabel,
                                    strings.formatBytes(sourceBytes.length),
                                  ),
                                row(strings.estimatedSizeLabel, estimateText),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
