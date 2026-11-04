import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/chat_image_editor_controller.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'editor_slider.dart';

/// The compress tool: a bottom sheet with a quality slider in steps of 10,
/// the original file size, a debounced size estimate and an apply button.
///
/// The slider is a draft: "Apply" keeps the quality and records it in the
/// history; tapping outside the sheet closes it without changing anything.
class CompressSheet extends StatefulWidget {
  /// Creates the sheet.
  const CompressSheet({super.key});

  /// Delay between the last slider move and the size estimate.
  static const Duration estimateDelay = Duration(milliseconds: 300);

  /// Lowest quality the slider offers.
  static const int minQuality = 10;

  /// Highest quality the slider offers.
  static const int maxQuality = 100;

  /// Distance between two slider stops.
  static const int qualityStep = 10;

  /// The slider stop that shows [quality]: the nearest multiple of
  /// [qualityStep] between [minQuality] and [maxQuality]. A quality from
  /// `ExportOptions.quality` needn't be one.
  static int stopFor(int quality) {
    final stop = (quality / qualityStep).round() * qualityStep;
    return stop.clamp(minQuality, maxQuality);
  }

  @override
  State<CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<CompressSheet> {
  Timer? _debounce;
  int _request = 0;
  int? _estimate;
  bool _estimating = false;
  late int _quality;
  ChatImageEditorController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ChatImageEditorScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller = controller;
      _quality = controller.quality;
      _scheduleEstimate(_quality);
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
    final quality = value.round();
    if (quality == _quality) return;
    setState(() {
      _quality = quality;
      _scheduleEstimate(quality);
    });
  }

  void _apply() {
    final controller = _controller;
    if (controller == null) return;
    // Applying the quality already in effect records nothing, even when it
    // comes from `ExportOptions.quality` rather than an earlier pick.
    if (_quality != controller.quality) {
      controller
        ..setQuality(_quality)
        ..commitQuality();
    }
    _close();
  }

  void _close() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.activeTool == EditorTool.compress) controller.closeTool();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final strings = scope.strings;
    final sourceBytes = scope.controller.sourceBytes;
    final estimate = _estimate;
    final stop = CompressSheet.stopFor(_quality);

    // Each row reads as one item: its label, then its value.
    Widget row(String label, Widget value) {
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(label, style: theme.sheetBodyStyle)),
              value,
            ],
          ),
        ),
      );
    }

    final Widget estimateValue;
    if (_estimating) {
      estimateValue = SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.primaryColor,
          semanticsLabel: strings.estimatingSize,
        ),
      );
    } else {
      estimateValue = Text(
        estimate == null ? '' : strings.formatBytes(estimate),
        style: theme.sheetBodyStyle,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        strings.compress,
                        style: theme.sheetTitleStyle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The slider below announces the same label and value.
                    ExcludeSemantics(
                      child: row(
                        strings.qualityLabel,
                        Text(
                          strings.formatQuality(_quality),
                          style: theme.sheetBodyStyle,
                        ),
                      ),
                    ),
                    EditorSlider(
                      value: stop.toDouble(),
                      min: CompressSheet.minQuality.toDouble(),
                      max: CompressSheet.maxQuality.toDouble(),
                      divisions:
                          (CompressSheet.maxQuality -
                              CompressSheet.minQuality) ~/
                          CompressSheet.qualityStep,
                      semanticsLabel: strings.qualityLabel,
                      // The thumb's stop reads as the draft itself, which
                      // can sit between stops.
                      semanticFormatterCallback: (value) {
                        final quality = value.round();
                        return strings.formatQuality(
                          quality == stop ? _quality : quality,
                        );
                      },
                      onChanged: _handleChanged,
                    ),
                    if (sourceBytes != null)
                      row(
                        strings.originalSizeLabel,
                        Text(
                          strings.formatBytes(sourceBytes.length),
                          style: theme.sheetBodyStyle,
                        ),
                      ),
                    row(strings.estimatedSizeLabel, estimateValue),
                    const SizedBox(height: 12),
                    _ApplyButton(label: strings.apply, onPressed: _apply),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The full-width button that applies the draft quality, in the send
/// button's colors.
class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: theme.sendButtonColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: theme.labelStyle.copyWith(
                  color: theme.sendButtonForegroundColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
