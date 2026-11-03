import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';
import '../theme/chat_image_editor_scope.dart';

/// Rebuilds only when a selected slice of the editor's controller changes.
///
/// The controller notifies on every edit (each sampled stroke point, for
/// example), so widgets that depend on a few fields select them here instead
/// of rebuilding on every notification. Selected values are compared with
/// `==`; records work well for selecting several fields at once.
class ControllerSelector<T> extends StatefulWidget {
  /// Creates a selector.
  const ControllerSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  /// Picks the value this widget depends on.
  final T Function(ChatImageEditorController controller) selector;

  /// Builds the widget for the selected value.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// Optional subtree passed through to [builder] unchanged.
  final Widget? child;

  @override
  State<ControllerSelector<T>> createState() => _ControllerSelectorState<T>();
}

class _ControllerSelectorState<T> extends State<ControllerSelector<T>> {
  ChatImageEditorController? _controller;
  late T _value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ChatImageEditorScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_handleChange);
      _controller = controller;
      controller.addListener(_handleChange);
      _value = widget.selector(controller);
    }
  }

  @override
  void didUpdateWidget(ControllerSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller != null) _value = widget.selector(controller);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final next = widget.selector(controller);
    if (next != _value) {
      setState(() => _value = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, widget.child);
  }
}
