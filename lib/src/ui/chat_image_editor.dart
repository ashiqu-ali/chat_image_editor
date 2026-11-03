import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/caption_field_config.dart';
import '../config/chat_image_editor_builders.dart';
import '../config/chat_image_editor_config.dart';
import '../controller/chat_image_editor_controller.dart';
import '../core/export/chat_image_editor_result.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_icons.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';
import 'discard_dialog.dart';
import 'editor_host.dart';
import 'editor_view.dart';

/// Runs an export and returns its result, or `null` on failure.
typedef ExportCallback = Future<ChatImageEditorResult?> Function();

/// Called on a long press of the send button with a way to export on
/// demand (for example after the user picks a time in a schedule sheet).
/// Return `true` to close the editor, `false` to stay.
typedef SendLongPressCallback =
    Future<bool> Function(BuildContext context, ExportCallback export);

/// A full-screen, WhatsApp-style image editor.
///
/// Use [ChatImageEditor.open] to push it as a route and await the result,
/// or embed the widget yourself and handle [onComplete] and [onCancel].
class ChatImageEditor extends StatefulWidget {
  /// Creates an editor for [image] (encoded bytes: JPEG, PNG, WebP, …).
  const ChatImageEditor({
    super.key,
    required this.image,
    this.controller,
    this.config = const ChatImageEditorConfig(),
    this.theme,
    this.icons = const ChatImageEditorIcons(),
    this.strings = const ChatImageEditorStrings(),
    this.captionField = const CaptionFieldConfig(),
    this.builders = const ChatImageEditorBuilders(),
    this.sendEnabled,
    this.onSendLongPress,
    this.onComplete,
    this.onCancel,
  });

  /// Encoded source image.
  final Uint8List image;

  /// Optional external controller. When `null` the editor creates and
  /// disposes its own.
  final ChatImageEditorController? controller;

  /// Behaviour configuration.
  final ChatImageEditorConfig config;

  /// Color and style overrides; see [ChatImageEditorThemeData].
  final ChatImageEditorThemeData? theme;

  /// Icon overrides.
  final ChatImageEditorIcons icons;

  /// Text overrides, for localization.
  final ChatImageEditorStrings strings;

  /// Caption `TextFormField` configuration (send mode).
  final CaptionFieldConfig captionField;

  /// Builders that replace parts of the UI.
  final ChatImageEditorBuilders builders;

  /// Disables the send button while `false`. `null` means always enabled.
  final ValueListenable<bool>? sendEnabled;

  /// Long-press action for the send button. `null` disables long press.
  final SendLongPressCallback? onSendLongPress;

  /// Called with the result after a successful send or done. When `null`,
  /// the editor pops its route with the result.
  final ValueChanged<ChatImageEditorResult>? onComplete;

  /// Called when the user closes the editor (after any discard
  /// confirmation). When `null`, the editor pops its route with `null`.
  final VoidCallback? onCancel;

  /// Pushes the editor as a full-screen route and completes with the
  /// result, or `null` if the user closed it.
  static Future<ChatImageEditorResult?> open(
    BuildContext context,
    Uint8List image, {
    ChatImageEditorController? controller,
    ChatImageEditorConfig config = const ChatImageEditorConfig(),
    ChatImageEditorThemeData? theme,
    ChatImageEditorIcons icons = const ChatImageEditorIcons(),
    ChatImageEditorStrings strings = const ChatImageEditorStrings(),
    CaptionFieldConfig captionField = const CaptionFieldConfig(),
    ChatImageEditorBuilders builders = const ChatImageEditorBuilders(),
    ValueListenable<bool>? sendEnabled,
    SendLongPressCallback? onSendLongPress,
    bool useRootNavigator = true,
  }) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    return navigator.push<ChatImageEditorResult>(
      MaterialPageRoute<ChatImageEditorResult>(
        fullscreenDialog: true,
        builder: (context) => ChatImageEditor(
          image: image,
          controller: controller,
          config: config,
          theme: theme,
          icons: icons,
          strings: strings,
          captionField: captionField,
          builders: builders,
          sendEnabled: sendEnabled,
          onSendLongPress: onSendLongPress,
        ),
      ),
    );
  }

  @override
  State<ChatImageEditor> createState() => _ChatImageEditorState();
}

class _ChatImageEditorState extends State<ChatImageEditor> {
  /// The constructor's default; an external controller keeps its own
  /// configuration when the widget is given this one.
  static const ChatImageEditorConfig _defaultConfig = ChatImageEditorConfig();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _deleteTargetKey = GlobalKey(debugLabel: 'deleteTarget');

  ChatImageEditorController? _ownController;
  TextEditingController? _ownCaption;
  String _captionInitial = '';
  ChatImageEditorResolvedTheme? _theme;

  bool _syncScheduled = false;
  (Color, Color)? _appliedColors;
  ChatImageEditorController? _colorsAppliedTo;
  Uint8List? _loadRequested;
  ChatImageEditorController? _loadRequestedOn;
  bool _closing = false;

  /// Whether the caption field still has to take focus when it first
  /// appears. `CaptionFieldConfig.autofocus` applies once per editor.
  late bool _captionAutofocusPending = widget.captionField.autofocus;

  ChatImageEditorController get _controller =>
      widget.controller ?? _ownController!;

  TextEditingController get _caption =>
      widget.captionField.controller ?? _ownCaption!;

  ChatImageEditorConfig get _config {
    final external = widget.controller;
    if (external != null && identical(widget.config, _defaultConfig)) {
      return external.config;
    }
    return widget.config;
  }

  bool get _captionInUse =>
      _config.mode == ChatImageEditorMode.send && widget.captionField.enabled;

  bool get _captionDirty =>
      _captionInUse && _caption.text.trim() != _captionInitial.trim();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownController = ChatImageEditorController(config: widget.config);
    }
    _attachCaption();
    _scheduleSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = ChatImageEditorThemeData.resolve(context, widget.theme);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(ChatImageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (widget.controller != null) {
        _disposeLater(_ownController);
        _ownController = null;
      } else {
        _ownController ??= ChatImageEditorController(config: widget.config);
      }
    }
    if (widget.theme != oldWidget.theme) {
      _theme = ChatImageEditorThemeData.resolve(context, widget.theme);
    }
    if (widget.captionField.controller != oldWidget.captionField.controller) {
      _attachCaption();
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _ownCaption?.dispose();
    super.dispose();
  }

  // ───────────────────────── Setup ─────────────────────────

  void _attachCaption() {
    final external = widget.captionField.controller;
    if (external != null) {
      final own = _ownCaption;
      _ownCaption = null;
      if (own != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => own.dispose());
      }
      _captionInitial = external.text;
    } else {
      final own = _ownCaption ??= TextEditingController(
        text: widget.captionField.initialValue ?? '',
      );
      _captionInitial = own.text;
    }
  }

  bool _takeCaptionAutofocus() {
    final pending = _captionAutofocusPending;
    _captionAutofocusPending = false;
    return pending;
  }

  void _disposeLater(ChatImageEditorController? controller) {
    if (controller == null) return;
    // Descendants still listen until they rebuild with the new controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  /// Pushes configuration, theme colors and the image into the controller
  /// after the frame, so listeners outside the editor are never notified
  /// while widgets build.
  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncController();
    });
  }

  void _syncController() {
    final controller = _controller;
    final config = _config;
    if (!identical(controller.config, config)) controller.config = config;

    final theme = _theme;
    if (theme != null) {
      // Export renders text with the same style the canvas previews.
      controller.textLayerStyle = theme.textLayerStyle;
      final colors = (theme.defaultDrawColor, theme.defaultTextColor);
      if (colors != _appliedColors ||
          !identical(controller, _colorsAppliedTo)) {
        _appliedColors = colors;
        _colorsAppliedTo = controller;
        controller.applyDefaultColors(
          drawColor: colors.$1,
          textColor: colors.$2,
        );
      }
    }

    _loadIfNeeded(controller);
  }

  void _loadIfNeeded(ChatImageEditorController controller) {
    final bytes = widget.image;
    if (identical(_loadRequested, bytes) &&
        identical(_loadRequestedOn, controller)) {
      return;
    }
    _loadRequested = bytes;
    _loadRequestedOn = controller;

    final status = controller.loadStatus;
    final source = controller.sourceBytes;
    final sameBytes =
        source != null &&
        (identical(source, bytes) || listEquals(source, bytes));
    if (sameBytes &&
        (status == ImageLoadStatus.loading ||
            status == ImageLoadStatus.ready)) {
      return;
    }
    unawaited(
      controller.load(bytes).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'chat_image_editor',
            context: ErrorDescription('while loading the image'),
          ),
        );
      }),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  bool _validateCaption() => _formKey.currentState?.validate() ?? true;

  bool _canSend() {
    final controller = _controller;
    if (controller.loadStatus != ImageLoadStatus.ready) return false;
    if (controller.isExporting) return false;
    return widget.sendEnabled?.value ?? true;
  }

  Future<ChatImageEditorResult?> _export() {
    final controller = _controller;
    if (controller.editingTextId != null) controller.finishTextEditing();
    return controller.export(caption: _captionInUse ? _caption.text : '');
  }

  Future<void> _send(BuildContext context) async {
    if (!_canSend() || !_validateCaption()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await _export();
    if (!mounted) return;
    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(widget.strings.exportFailed)));
      }
      return;
    }
    final onComplete = widget.onComplete;
    if (onComplete != null) {
      onComplete(result);
    } else {
      _popRoute(result);
    }
  }

  Future<void> _sendLongPress(BuildContext context) async {
    final callback = widget.onSendLongPress;
    if (callback == null || !_canSend() || !_validateCaption()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final close = await callback(context, _export);
    if (!close || !mounted) return;
    // The host received the export through the callback and handles it
    // itself (for example by scheduling it), so the editor closes without a
    // result rather than reporting it a second time.
    _cancel();
  }

  Future<void> _close(BuildContext context) async {
    if (_closing) return;
    _closing = true;
    try {
      final controller = _controller;
      final unsaved = controller.hasChanges || _captionDirty;
      if (_config.confirmDiscard && unsaved) {
        final confirm = widget.builders.confirmDiscard ?? showDiscardDialog;
        final discard = await confirm(context);
        if (!discard || !mounted) return;
      }
      _cancel();
    } finally {
      _closing = false;
    }
  }

  /// System back: first closes text entry or the open tool, then closes the
  /// editor like the close button.
  void _handleBack(BuildContext context) {
    final controller = _controller;
    if (controller.loadStatus == ImageLoadStatus.ready) {
      if (controller.isExporting) return;
      if (controller.editingTextId != null) {
        controller.finishTextEditing();
        if (controller.activeTool == EditorTool.text) controller.closeTool();
        return;
      }
      switch (controller.activeTool) {
        case EditorTool.crop:
          controller.cancelCrop();
          if (controller.activeTool == EditorTool.crop) controller.closeTool();
          return;
        case EditorTool.compress:
          controller.commitQuality();
          if (controller.activeTool == EditorTool.compress) {
            controller.closeTool();
          }
          return;
        case EditorTool.draw:
        case EditorTool.text:
          controller.closeTool();
          return;
        case EditorTool.none:
          break;
      }
    }
    unawaited(_close(context));
  }

  void _cancel() {
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
    } else {
      _popRoute(null);
    }
  }

  void _popRoute(ChatImageEditorResult? result) {
    final navigator = Navigator.maybeOf(context);
    final route = ModalRoute.of(context);
    if (navigator == null || route == null || !route.isCurrent) return;
    if (navigator.canPop()) navigator.pop(result);
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = _theme ??= ChatImageEditorThemeData.resolve(
      context,
      widget.theme,
    );
    final overlayStyle =
        ThemeData.estimateBrightnessForColor(theme.backgroundColor) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ChatImageEditorScope(
      controller: _controller,
      theme: theme,
      icons: widget.icons,
      strings: widget.strings,
      config: _config,
      captionField: widget.captionField,
      builders: widget.builders,
      child: EditorHost(
        captionController: _caption,
        formKey: _formKey,
        deleteTargetKey: _deleteTargetKey,
        send: _send,
        close: _close,
        sendLongPress: widget.onSendLongPress == null ? null : _sendLongPress,
        sendEnabled: widget.sendEnabled,
        takeCaptionAutofocus: _takeCaptionAutofocus,
        child: TextSelectionTheme(
          data: TextSelectionThemeData(
            cursorColor: theme.primaryColor,
            selectionColor: theme.primaryColor.withValues(alpha: 0.4),
            selectionHandleColor: theme.primaryColor,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: Builder(
              builder: (scopedContext) => PopScope<Object?>(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _handleBack(scopedContext);
                },
                child: const EditorView(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
