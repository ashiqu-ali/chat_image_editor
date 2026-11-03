import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colors, text styles and sizes for the editor.
///
/// Every field is optional. A `null` field falls back, in order, to:
///
/// 1. the same field of a `ChatImageEditorThemeData` registered as a
///    `ThemeExtension` on the app's `ThemeData`, then
/// 2. a default derived from the app's `ColorScheme` and `TextTheme`
///    (accent colors use `colorScheme.primary`).
///
/// So the editor matches the host app out of the box, and any single color
/// can be overridden:
///
/// ```dart
/// ChatImageEditor(
///   image: bytes,
///   theme: const ChatImageEditorThemeData(sendButtonColor: Colors.teal),
/// );
/// ```
@immutable
class ChatImageEditorThemeData
    extends ThemeExtension<ChatImageEditorThemeData> {
  /// Creates theme overrides. Leave a field `null` to inherit it.
  const ChatImageEditorThemeData({
    this.primaryColor,
    this.onPrimaryColor,
    this.backgroundColor,
    this.foregroundColor,
    this.toolbarBackgroundColor,
    this.activeToolColor,
    this.scrimColor,
    this.cropFrameColor,
    this.cropHandleColor,
    this.cropGridColor,
    this.cropOverlayColor,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.deleteTargetColor,
    this.deleteTargetActiveColor,
    this.guideLineColor,
    this.captionFillColor,
    this.captionTextColor,
    this.captionHintColor,
    this.sendButtonColor,
    this.sendButtonForegroundColor,
    this.sendButtonDisabledColor,
    this.sheetBackgroundColor,
    this.sheetForegroundColor,
    this.defaultDrawColor,
    this.defaultTextColor,
    this.loadingIndicatorColor,
    this.palette,
    this.labelStyle,
    this.captionStyle,
    this.sheetTitleStyle,
    this.sheetBodyStyle,
    this.textLayerStyle,
    this.iconSize,
    this.captionBorderRadius,
    this.sendButtonSize,
  });

  /// Accent used by every "primary" element unless overridden below.
  /// Defaults to `ColorScheme.primary`.
  final Color? primaryColor;

  /// Content on top of [primaryColor]. Defaults to `ColorScheme.onPrimary`.
  final Color? onPrimaryColor;

  /// Editor background around the image. Defaults to black.
  final Color? backgroundColor;

  /// Icons and labels drawn over the editor background. Defaults to white.
  final Color? foregroundColor;

  /// Circular backdrop behind top-bar buttons, for contrast on bright
  /// photos. Defaults to translucent black.
  final Color? toolbarBackgroundColor;

  /// Highlight for the selected tool and shape. Defaults to [primaryColor].
  final Color? activeToolColor;

  /// Dim layer behind the text entry overlay. Defaults to translucent black.
  final Color? scrimColor;

  /// Crop frame border. Defaults to white.
  final Color? cropFrameColor;

  /// Crop corner handles. Defaults to white.
  final Color? cropHandleColor;

  /// Rule-of-thirds grid inside the crop frame. Defaults to translucent
  /// white.
  final Color? cropGridColor;

  /// Shade over the area outside the crop frame. Defaults to translucent
  /// black.
  final Color? cropOverlayColor;

  /// Filled part of sliders. Defaults to [primaryColor].
  final Color? sliderActiveColor;

  /// Unfilled part of sliders. Defaults to translucent white.
  final Color? sliderInactiveColor;

  /// Slider thumb. Defaults to white.
  final Color? sliderThumbColor;

  /// Drag-to-delete target at rest. Defaults to translucent black.
  final Color? deleteTargetColor;

  /// Drag-to-delete target while a layer hovers over it. Defaults to
  /// `ColorScheme.error`.
  final Color? deleteTargetActiveColor;

  /// Snap guide lines shown while moving text. Defaults to [primaryColor].
  final Color? guideLineColor;

  /// Caption field fill. Defaults to dark grey.
  final Color? captionFillColor;

  /// Caption text. Defaults to white.
  final Color? captionTextColor;

  /// Caption hint. Defaults to translucent white.
  final Color? captionHintColor;

  /// Send and done button background. Defaults to [primaryColor].
  final Color? sendButtonColor;

  /// Send and done button icon and busy spinner. Defaults to
  /// [onPrimaryColor].
  final Color? sendButtonForegroundColor;

  /// Send button background while disabled. Defaults to grey.
  final Color? sendButtonDisabledColor;

  /// Background of bottom sheets such as the compress sheet. Defaults to
  /// near-black.
  final Color? sheetBackgroundColor;

  /// Text and icons on bottom sheets. Defaults to white.
  final Color? sheetForegroundColor;

  /// First color of the draw tool. Defaults to [primaryColor].
  final Color? defaultDrawColor;

  /// First color of the text tool. Defaults to white.
  final Color? defaultTextColor;

  /// Image loading indicator. Defaults to [primaryColor]. The send
  /// button's busy spinner uses [sendButtonForegroundColor].
  final Color? loadingIndicatorColor;

  /// Colors offered by the color strip, top to bottom. Defaults to
  /// [ChatImageEditorThemeData.defaultPalette].
  final List<Color>? palette;

  /// Small labels such as aspect-ratio chips. Merged onto the default, so
  /// a style without a color keeps [foregroundColor].
  final TextStyle? labelStyle;

  /// Typed caption text. Merged onto the default, so a style without a
  /// color keeps [captionTextColor].
  final TextStyle? captionStyle;

  /// Bottom sheet titles. Merged onto the default, so a style without a
  /// color keeps [sheetForegroundColor].
  final TextStyle? sheetTitleStyle;

  /// Bottom sheet body text. Merged onto the default, so a style without a
  /// color keeps [sheetForegroundColor].
  final TextStyle? sheetBodyStyle;

  /// Base style for text layers drawn on the image (font family, weight,
  /// shadows). Color and size always come from the layer itself, and the
  /// same style is used for the export so output matches the preview.
  final TextStyle? textLayerStyle;

  /// Size of top-bar and toolbar icons. Defaults to 24.
  final double? iconSize;

  /// Corner radius of the caption field. Defaults to 24.
  final BorderRadius? captionBorderRadius;

  /// Diameter of the send and done buttons. Defaults to 52.
  final double? sendButtonSize;

  /// Colors offered when [palette] is `null`.
  static const List<Color> defaultPalette = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
  ];

  /// Returns a copy where every non-null field of [other] wins.
  ChatImageEditorThemeData merge(ChatImageEditorThemeData? other) {
    if (other == null) return this;
    return copyWith(
      primaryColor: other.primaryColor,
      onPrimaryColor: other.onPrimaryColor,
      backgroundColor: other.backgroundColor,
      foregroundColor: other.foregroundColor,
      toolbarBackgroundColor: other.toolbarBackgroundColor,
      activeToolColor: other.activeToolColor,
      scrimColor: other.scrimColor,
      cropFrameColor: other.cropFrameColor,
      cropHandleColor: other.cropHandleColor,
      cropGridColor: other.cropGridColor,
      cropOverlayColor: other.cropOverlayColor,
      sliderActiveColor: other.sliderActiveColor,
      sliderInactiveColor: other.sliderInactiveColor,
      sliderThumbColor: other.sliderThumbColor,
      deleteTargetColor: other.deleteTargetColor,
      deleteTargetActiveColor: other.deleteTargetActiveColor,
      guideLineColor: other.guideLineColor,
      captionFillColor: other.captionFillColor,
      captionTextColor: other.captionTextColor,
      captionHintColor: other.captionHintColor,
      sendButtonColor: other.sendButtonColor,
      sendButtonForegroundColor: other.sendButtonForegroundColor,
      sendButtonDisabledColor: other.sendButtonDisabledColor,
      sheetBackgroundColor: other.sheetBackgroundColor,
      sheetForegroundColor: other.sheetForegroundColor,
      defaultDrawColor: other.defaultDrawColor,
      defaultTextColor: other.defaultTextColor,
      loadingIndicatorColor: other.loadingIndicatorColor,
      palette: other.palette,
      labelStyle: other.labelStyle,
      captionStyle: other.captionStyle,
      sheetTitleStyle: other.sheetTitleStyle,
      sheetBodyStyle: other.sheetBodyStyle,
      textLayerStyle: other.textLayerStyle,
      iconSize: other.iconSize,
      captionBorderRadius: other.captionBorderRadius,
      sendButtonSize: other.sendButtonSize,
    );
  }

  /// Resolves every field for [context]: [override] first, then the app's
  /// `ChatImageEditorThemeData` extension, then defaults from the app's
  /// `ColorScheme` and `TextTheme`.
  static ChatImageEditorResolvedTheme resolve(
    BuildContext context, [
    ChatImageEditorThemeData? override,
  ]) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final t =
        (theme.extension<ChatImageEditorThemeData>() ??
                const ChatImageEditorThemeData())
            .merge(override);

    final primary = t.primaryColor ?? scheme.primary;
    final onPrimary = t.onPrimaryColor ?? scheme.onPrimary;
    final foreground = t.foregroundColor ?? const Color(0xFFFFFFFF);
    final captionText = t.captionTextColor ?? const Color(0xFFFFFFFF);
    final sheetForeground = t.sheetForegroundColor ?? const Color(0xFFFFFFFF);

    return ChatImageEditorResolvedTheme(
      primaryColor: primary,
      onPrimaryColor: onPrimary,
      backgroundColor: t.backgroundColor ?? const Color(0xFF000000),
      foregroundColor: foreground,
      toolbarBackgroundColor:
          t.toolbarBackgroundColor ?? const Color(0x59000000),
      activeToolColor: t.activeToolColor ?? primary,
      scrimColor: t.scrimColor ?? const Color(0x99000000),
      cropFrameColor: t.cropFrameColor ?? const Color(0xFFFFFFFF),
      cropHandleColor: t.cropHandleColor ?? const Color(0xFFFFFFFF),
      cropGridColor: t.cropGridColor ?? const Color(0x80FFFFFF),
      cropOverlayColor: t.cropOverlayColor ?? const Color(0x99000000),
      sliderActiveColor: t.sliderActiveColor ?? primary,
      sliderInactiveColor: t.sliderInactiveColor ?? const Color(0x4DFFFFFF),
      sliderThumbColor: t.sliderThumbColor ?? const Color(0xFFFFFFFF),
      deleteTargetColor: t.deleteTargetColor ?? const Color(0x8A000000),
      deleteTargetActiveColor: t.deleteTargetActiveColor ?? scheme.error,
      guideLineColor: t.guideLineColor ?? primary,
      captionFillColor: t.captionFillColor ?? const Color(0xFF262626),
      captionTextColor: captionText,
      captionHintColor: t.captionHintColor ?? const Color(0x99FFFFFF),
      sendButtonColor: t.sendButtonColor ?? primary,
      sendButtonForegroundColor: t.sendButtonForegroundColor ?? onPrimary,
      sendButtonDisabledColor:
          t.sendButtonDisabledColor ?? const Color(0xFF5C5C5C),
      sheetBackgroundColor: t.sheetBackgroundColor ?? const Color(0xFF1E1E1E),
      sheetForegroundColor: sheetForeground,
      defaultDrawColor: t.defaultDrawColor ?? primary,
      defaultTextColor: t.defaultTextColor ?? const Color(0xFFFFFFFF),
      loadingIndicatorColor: t.loadingIndicatorColor ?? primary,
      palette: t.palette ?? defaultPalette,
      // A style override is merged onto the colored default, so one that
      // only changes, say, the size keeps the themed color.
      labelStyle: (textTheme.labelLarge ?? const TextStyle(fontSize: 14))
          .copyWith(color: foreground)
          .merge(t.labelStyle),
      captionStyle: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16))
          .copyWith(color: captionText)
          .merge(t.captionStyle),
      sheetTitleStyle: (textTheme.titleMedium ?? const TextStyle(fontSize: 16))
          .copyWith(color: sheetForeground)
          .merge(t.sheetTitleStyle),
      sheetBodyStyle: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(color: sheetForeground)
          .merge(t.sheetBodyStyle),
      textLayerStyle:
          t.textLayerStyle ??
          TextStyle(
            fontFamily: textTheme.bodyLarge?.fontFamily,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
      iconSize: t.iconSize ?? 24,
      captionBorderRadius:
          t.captionBorderRadius ?? const BorderRadius.all(Radius.circular(24)),
      sendButtonSize: t.sendButtonSize ?? 52,
    );
  }

  @override
  ChatImageEditorThemeData copyWith({
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? toolbarBackgroundColor,
    Color? activeToolColor,
    Color? scrimColor,
    Color? cropFrameColor,
    Color? cropHandleColor,
    Color? cropGridColor,
    Color? cropOverlayColor,
    Color? sliderActiveColor,
    Color? sliderInactiveColor,
    Color? sliderThumbColor,
    Color? deleteTargetColor,
    Color? deleteTargetActiveColor,
    Color? guideLineColor,
    Color? captionFillColor,
    Color? captionTextColor,
    Color? captionHintColor,
    Color? sendButtonColor,
    Color? sendButtonForegroundColor,
    Color? sendButtonDisabledColor,
    Color? sheetBackgroundColor,
    Color? sheetForegroundColor,
    Color? defaultDrawColor,
    Color? defaultTextColor,
    Color? loadingIndicatorColor,
    List<Color>? palette,
    TextStyle? labelStyle,
    TextStyle? captionStyle,
    TextStyle? sheetTitleStyle,
    TextStyle? sheetBodyStyle,
    TextStyle? textLayerStyle,
    double? iconSize,
    BorderRadius? captionBorderRadius,
    double? sendButtonSize,
  }) {
    return ChatImageEditorThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      toolbarBackgroundColor:
          toolbarBackgroundColor ?? this.toolbarBackgroundColor,
      activeToolColor: activeToolColor ?? this.activeToolColor,
      scrimColor: scrimColor ?? this.scrimColor,
      cropFrameColor: cropFrameColor ?? this.cropFrameColor,
      cropHandleColor: cropHandleColor ?? this.cropHandleColor,
      cropGridColor: cropGridColor ?? this.cropGridColor,
      cropOverlayColor: cropOverlayColor ?? this.cropOverlayColor,
      sliderActiveColor: sliderActiveColor ?? this.sliderActiveColor,
      sliderInactiveColor: sliderInactiveColor ?? this.sliderInactiveColor,
      sliderThumbColor: sliderThumbColor ?? this.sliderThumbColor,
      deleteTargetColor: deleteTargetColor ?? this.deleteTargetColor,
      deleteTargetActiveColor:
          deleteTargetActiveColor ?? this.deleteTargetActiveColor,
      guideLineColor: guideLineColor ?? this.guideLineColor,
      captionFillColor: captionFillColor ?? this.captionFillColor,
      captionTextColor: captionTextColor ?? this.captionTextColor,
      captionHintColor: captionHintColor ?? this.captionHintColor,
      sendButtonColor: sendButtonColor ?? this.sendButtonColor,
      sendButtonForegroundColor:
          sendButtonForegroundColor ?? this.sendButtonForegroundColor,
      sendButtonDisabledColor:
          sendButtonDisabledColor ?? this.sendButtonDisabledColor,
      sheetBackgroundColor: sheetBackgroundColor ?? this.sheetBackgroundColor,
      sheetForegroundColor: sheetForegroundColor ?? this.sheetForegroundColor,
      defaultDrawColor: defaultDrawColor ?? this.defaultDrawColor,
      defaultTextColor: defaultTextColor ?? this.defaultTextColor,
      loadingIndicatorColor:
          loadingIndicatorColor ?? this.loadingIndicatorColor,
      palette: palette ?? this.palette,
      labelStyle: labelStyle ?? this.labelStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      sheetTitleStyle: sheetTitleStyle ?? this.sheetTitleStyle,
      sheetBodyStyle: sheetBodyStyle ?? this.sheetBodyStyle,
      textLayerStyle: textLayerStyle ?? this.textLayerStyle,
      iconSize: iconSize ?? this.iconSize,
      captionBorderRadius: captionBorderRadius ?? this.captionBorderRadius,
      sendButtonSize: sendButtonSize ?? this.sendButtonSize,
    );
  }

  @override
  ChatImageEditorThemeData lerp(
    covariant ThemeExtension<ChatImageEditorThemeData>? other,
    double t,
  ) {
    if (other is! ChatImageEditorThemeData) return this;
    Color? c(Color? a, Color? b) => Color.lerp(a, b, t);
    TextStyle? s(TextStyle? a, TextStyle? b) => TextStyle.lerp(a, b, t);
    return ChatImageEditorThemeData(
      primaryColor: c(primaryColor, other.primaryColor),
      onPrimaryColor: c(onPrimaryColor, other.onPrimaryColor),
      backgroundColor: c(backgroundColor, other.backgroundColor),
      foregroundColor: c(foregroundColor, other.foregroundColor),
      toolbarBackgroundColor: c(
        toolbarBackgroundColor,
        other.toolbarBackgroundColor,
      ),
      activeToolColor: c(activeToolColor, other.activeToolColor),
      scrimColor: c(scrimColor, other.scrimColor),
      cropFrameColor: c(cropFrameColor, other.cropFrameColor),
      cropHandleColor: c(cropHandleColor, other.cropHandleColor),
      cropGridColor: c(cropGridColor, other.cropGridColor),
      cropOverlayColor: c(cropOverlayColor, other.cropOverlayColor),
      sliderActiveColor: c(sliderActiveColor, other.sliderActiveColor),
      sliderInactiveColor: c(sliderInactiveColor, other.sliderInactiveColor),
      sliderThumbColor: c(sliderThumbColor, other.sliderThumbColor),
      deleteTargetColor: c(deleteTargetColor, other.deleteTargetColor),
      deleteTargetActiveColor: c(
        deleteTargetActiveColor,
        other.deleteTargetActiveColor,
      ),
      guideLineColor: c(guideLineColor, other.guideLineColor),
      captionFillColor: c(captionFillColor, other.captionFillColor),
      captionTextColor: c(captionTextColor, other.captionTextColor),
      captionHintColor: c(captionHintColor, other.captionHintColor),
      sendButtonColor: c(sendButtonColor, other.sendButtonColor),
      sendButtonForegroundColor: c(
        sendButtonForegroundColor,
        other.sendButtonForegroundColor,
      ),
      sendButtonDisabledColor: c(
        sendButtonDisabledColor,
        other.sendButtonDisabledColor,
      ),
      sheetBackgroundColor: c(sheetBackgroundColor, other.sheetBackgroundColor),
      sheetForegroundColor: c(sheetForegroundColor, other.sheetForegroundColor),
      defaultDrawColor: c(defaultDrawColor, other.defaultDrawColor),
      defaultTextColor: c(defaultTextColor, other.defaultTextColor),
      loadingIndicatorColor: c(
        loadingIndicatorColor,
        other.loadingIndicatorColor,
      ),
      palette: t < 0.5 ? palette : other.palette,
      labelStyle: s(labelStyle, other.labelStyle),
      captionStyle: s(captionStyle, other.captionStyle),
      sheetTitleStyle: s(sheetTitleStyle, other.sheetTitleStyle),
      sheetBodyStyle: s(sheetBodyStyle, other.sheetBodyStyle),
      textLayerStyle: s(textLayerStyle, other.textLayerStyle),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      captionBorderRadius: BorderRadius.lerp(
        captionBorderRadius,
        other.captionBorderRadius,
        t,
      ),
      sendButtonSize: lerpDouble(sendButtonSize, other.sendButtonSize, t),
    );
  }
}

/// A [ChatImageEditorThemeData] with every value filled in.
///
/// Produced by [ChatImageEditorThemeData.resolve] and read by the editor's
/// widgets through `ChatImageEditorScope.of(context).theme`. Custom builders
/// can use it to match the editor's look.
@immutable
class ChatImageEditorResolvedTheme {
  /// Creates a fully resolved theme.
  const ChatImageEditorResolvedTheme({
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.toolbarBackgroundColor,
    required this.activeToolColor,
    required this.scrimColor,
    required this.cropFrameColor,
    required this.cropHandleColor,
    required this.cropGridColor,
    required this.cropOverlayColor,
    required this.sliderActiveColor,
    required this.sliderInactiveColor,
    required this.sliderThumbColor,
    required this.deleteTargetColor,
    required this.deleteTargetActiveColor,
    required this.guideLineColor,
    required this.captionFillColor,
    required this.captionTextColor,
    required this.captionHintColor,
    required this.sendButtonColor,
    required this.sendButtonForegroundColor,
    required this.sendButtonDisabledColor,
    required this.sheetBackgroundColor,
    required this.sheetForegroundColor,
    required this.defaultDrawColor,
    required this.defaultTextColor,
    required this.loadingIndicatorColor,
    required this.palette,
    required this.labelStyle,
    required this.captionStyle,
    required this.sheetTitleStyle,
    required this.sheetBodyStyle,
    required this.textLayerStyle,
    required this.iconSize,
    required this.captionBorderRadius,
    required this.sendButtonSize,
  });

  /// See [ChatImageEditorThemeData.primaryColor].
  final Color primaryColor;

  /// See [ChatImageEditorThemeData.onPrimaryColor].
  final Color onPrimaryColor;

  /// See [ChatImageEditorThemeData.backgroundColor].
  final Color backgroundColor;

  /// See [ChatImageEditorThemeData.foregroundColor].
  final Color foregroundColor;

  /// See [ChatImageEditorThemeData.toolbarBackgroundColor].
  final Color toolbarBackgroundColor;

  /// See [ChatImageEditorThemeData.activeToolColor].
  final Color activeToolColor;

  /// See [ChatImageEditorThemeData.scrimColor].
  final Color scrimColor;

  /// See [ChatImageEditorThemeData.cropFrameColor].
  final Color cropFrameColor;

  /// See [ChatImageEditorThemeData.cropHandleColor].
  final Color cropHandleColor;

  /// See [ChatImageEditorThemeData.cropGridColor].
  final Color cropGridColor;

  /// See [ChatImageEditorThemeData.cropOverlayColor].
  final Color cropOverlayColor;

  /// See [ChatImageEditorThemeData.sliderActiveColor].
  final Color sliderActiveColor;

  /// See [ChatImageEditorThemeData.sliderInactiveColor].
  final Color sliderInactiveColor;

  /// See [ChatImageEditorThemeData.sliderThumbColor].
  final Color sliderThumbColor;

  /// See [ChatImageEditorThemeData.deleteTargetColor].
  final Color deleteTargetColor;

  /// See [ChatImageEditorThemeData.deleteTargetActiveColor].
  final Color deleteTargetActiveColor;

  /// See [ChatImageEditorThemeData.guideLineColor].
  final Color guideLineColor;

  /// See [ChatImageEditorThemeData.captionFillColor].
  final Color captionFillColor;

  /// See [ChatImageEditorThemeData.captionTextColor].
  final Color captionTextColor;

  /// See [ChatImageEditorThemeData.captionHintColor].
  final Color captionHintColor;

  /// See [ChatImageEditorThemeData.sendButtonColor].
  final Color sendButtonColor;

  /// See [ChatImageEditorThemeData.sendButtonForegroundColor].
  final Color sendButtonForegroundColor;

  /// See [ChatImageEditorThemeData.sendButtonDisabledColor].
  final Color sendButtonDisabledColor;

  /// See [ChatImageEditorThemeData.sheetBackgroundColor].
  final Color sheetBackgroundColor;

  /// See [ChatImageEditorThemeData.sheetForegroundColor].
  final Color sheetForegroundColor;

  /// See [ChatImageEditorThemeData.defaultDrawColor].
  final Color defaultDrawColor;

  /// See [ChatImageEditorThemeData.defaultTextColor].
  final Color defaultTextColor;

  /// See [ChatImageEditorThemeData.loadingIndicatorColor].
  final Color loadingIndicatorColor;

  /// See [ChatImageEditorThemeData.palette].
  final List<Color> palette;

  /// See [ChatImageEditorThemeData.labelStyle].
  final TextStyle labelStyle;

  /// See [ChatImageEditorThemeData.captionStyle].
  final TextStyle captionStyle;

  /// See [ChatImageEditorThemeData.sheetTitleStyle].
  final TextStyle sheetTitleStyle;

  /// See [ChatImageEditorThemeData.sheetBodyStyle].
  final TextStyle sheetBodyStyle;

  /// See [ChatImageEditorThemeData.textLayerStyle].
  final TextStyle textLayerStyle;

  /// See [ChatImageEditorThemeData.iconSize].
  final double iconSize;

  /// See [ChatImageEditorThemeData.captionBorderRadius].
  final BorderRadius captionBorderRadius;

  /// See [ChatImageEditorThemeData.sendButtonSize].
  final double sendButtonSize;
}
