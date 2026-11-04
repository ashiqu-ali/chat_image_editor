# Customization reference

Everything you can change in `chat_image_editor`, with defaults and short
examples. Every option is optional: the editor works and matches your app
with no configuration at all.

All parameters below are available both on the `ChatImageEditor` widget and
on `ChatImageEditor.open`.

| Parameter | Type | What it customizes |
|---|---|---|
| `theme` | `ChatImageEditorThemeData?` | [Colors, text styles and sizes](#theme) |
| `icons` | `ChatImageEditorIcons` | [Every icon](#icons) |
| `strings` | `ChatImageEditorStrings` | [Every string, for localization](#strings) |
| `captionField` | `CaptionFieldConfig` | [The caption `TextFormField`](#caption-field) |
| `builders` | `ChatImageEditorBuilders` | [Whole UI regions](#builders) |
| `config` | `ChatImageEditorConfig` | [Tools and behaviour](#behaviour) and [export](#export-options) |
| `controller` | `ChatImageEditorController?` | [State and actions from code](#controller) |
| `sendEnabled` | `ValueListenable<bool>?` | [Enabling the send button](#send-button-behaviour) |
| `onSendLongPress` | `SendLongPressCallback?` | [Long press on send](#send-button-behaviour) |

The widget also takes `onComplete` and `onCancel` (see
[Embedding](#embedding)), and `open` takes `useRootNavigator`
(default `true`).

Contents:

- [Where things appear](#where-things-appear)
- [Theme](#theme)
- [Icons](#icons)
- [Strings](#strings)
- [Caption field](#caption-field)
- [Builders](#builders)
- [Send button behaviour](#send-button-behaviour)
- [Behaviour](#behaviour)
- [Export options](#export-options)
- [Controller](#controller)
- [Embedding](#embedding)

## Where things appear

The tables below refer to these parts of the editor:

| Screen | What it shows |
|---|---|
| Preview (no tool open) | Top bar: close on the left; undo, redo and the tool buttons on the right. Bottom: the caption field, with the recipient chip (`CaptionFieldConfig.header`) and the send button below it. In done mode, a single done button. |
| Draw | The top bar morphs: close becomes a **Done** pill, and the tools fold into undo plus a swatch of the pen color (tap it, or Done, to stop drawing). A vertical gradient color slider runs down the right edge. The bottom shows the shape picker and the brush size slider. |
| Text entry | A dimmed overlay with a **Done** pill, the text background toggle and the same color slider. |
| Crop | Aspect-ratio chips, then one bottom row: cancel, rotate left, rotate right, flip horizontally, flip vertically, reset and confirm. |
| Compress | A bottom sheet: title, the quality (`Low · 40`, `Medium · 70`, `High · 90`) with a slider in steps of 10, the original size, a live size estimate and an **Apply** button. Tapping outside the sheet closes it without changing anything. |
| Close with unsaved edits | A discard confirmation. It's platform-adaptive: a Cupertino alert on iOS and macOS, a Material dialog elsewhere. |

While a stroke is being drawn or a text layer is being moved, the chrome
fades out so the photo stays in view. The bottom controls sit on a scrim
(`scrimColor`) that fades up into the photo.

## Theme

`ChatImageEditorThemeData` holds every color, text style and size the editor
uses. Every field is optional.

### How a value is resolved

For each field, the editor uses the first non-null value from:

1. the `theme` passed to `ChatImageEditor` or `ChatImageEditor.open`,
2. a `ChatImageEditorThemeData` registered in your app's
   `ThemeData.extensions`,
3. the default listed below, derived from your app's `ColorScheme` and
   `TextTheme`.

So you can set a brand look once as an extension and tweak a single field
for one screen:

```dart
// Once, for the whole app.
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    extensions: const [
      ChatImageEditorThemeData(captionFillColor: Color(0xFF1F2C34)),
    ],
  ),
  home: const HomePage(),
);

// For one screen: this wins over the extension, field by field.
ChatImageEditor.open(
  context,
  photo,
  theme: const ChatImageEditorThemeData(sendButtonColor: Colors.orange),
);
```

The defaults keep the editor dark in both light and dark app themes, so
photos stand out. Only the accents follow your `ColorScheme`. Setting
`primaryColor` changes every field that defaults to it.

`ChatImageEditorThemeData` is a `ThemeExtension`, so it also supports
`copyWith`, `lerp` (animated theme changes) and `merge`.

### Colors

"Translucent" values are given as alpha percentages.

| Field | What it colors | Default |
|---|---|---|
| `primaryColor` | Accent for every "primary" element unless overridden below. | `ColorScheme.primary` |
| `onPrimaryColor` | Content on top of `primaryColor`. | `ColorScheme.onPrimary` |
| `backgroundColor` | Editor background around the image. | Black |
| `foregroundColor` | Icons and labels drawn over the editor background. | White |
| `toolbarBackgroundColor` | Backdrop behind the editor's buttons, the **Done** pill, unselected aspect-ratio chips and the recipient chip, for contrast on bright photos. | Black, 54% |
| `activeToolColor` | Icon color of the selected tool and shape, and the selected aspect-ratio chip. | `primaryColor` |
| `scrimColor` | Dim layer behind the text entry overlay, and the gradient under the bottom controls. | Black, 60% |
| `cropFrameColor` | Crop frame border. | White |
| `cropHandleColor` | Crop corner handles. | White |
| `cropGridColor` | Rule-of-thirds grid inside the crop frame. | White, 50% |
| `cropOverlayColor` | Shade over the area outside the crop frame. | Black, 60% |
| `sliderActiveColor` | Filled part of sliders (brush size, quality). | `primaryColor` |
| `sliderInactiveColor` | Unfilled part of sliders. | White, 30% |
| `sliderThumbColor` | Slider thumb. | White |
| `deleteTargetColor` | Drag-to-delete target at rest. | Black, 54% |
| `deleteTargetActiveColor` | Drag-to-delete target while a text layer is over it. | `ColorScheme.error` |
| `guideLineColor` | Center snap guides shown while moving text. | `primaryColor` |
| `captionFillColor` | Caption field fill. Translucent, so the photo shows through. | Black, 54% |
| `captionTextColor` | Caption text. | White |
| `captionHintColor` | Caption hint. | White, 60% |
| `sendButtonColor` | Send and done button background, and the compress sheet's **Apply** button. | `primaryColor` |
| `sendButtonForegroundColor` | Send and done button icon, their busy spinner, and the **Apply** label. | `onPrimaryColor` |
| `sendButtonDisabledColor` | Send button background while disabled. | Grey `#5C5C5C` |
| `sheetBackgroundColor` | Background of bottom sheets, such as the compress sheet. | Near-black `#1E1E1E` |
| `sheetForegroundColor` | Text and icons on bottom sheets. | White |
| `defaultDrawColor` | First pen color, shown in the pen-color swatch. | `primaryColor` |
| `defaultTextColor` | First color of the text tool. | White |
| `loadingIndicatorColor` | Image loading indicator. The send button's busy spinner uses `sendButtonForegroundColor`. | `primaryColor` |
| `palette` | Stops of the vertical gradient color slider, top to bottom. | `ChatImageEditorThemeData.defaultPalette` |

`defaultPalette` is white, black, red, orange, yellow, green, cyan, blue,
purple and pink. The color slider blends between neighbouring stops, so the
user can pick any color along the gradient; each stop is picked exactly at
its own position.

### Text styles

| Field | What it styles | Default |
|---|---|---|
| `labelStyle` | Small labels: aspect-ratio chips, the **Done** pill, the recipient chip and the **Apply** button. | `TextTheme.labelLarge` in `foregroundColor` |
| `captionStyle` | Typed caption text. | `TextTheme.bodyLarge` in `captionTextColor` |
| `sheetTitleStyle` | Bottom sheet titles. | `TextTheme.titleMedium` in `sheetForegroundColor` |
| `sheetBodyStyle` | Bottom sheet body text. | `TextTheme.bodyMedium` in `sheetForegroundColor` |
| `textLayerStyle` | Base style of text drawn on the image: font family, weight, shadows. | Your app's body font, weight 600, line height 1.2 |

A `labelStyle`, `captionStyle`, `sheetTitleStyle` or `sheetBodyStyle` you set
is merged onto its default. A style that only changes the font or size keeps
the themed color; a color in your style wins. Pass a style with
`inherit: false` to replace the default completely.

Text layers always take their color and size from the layer itself. The same
`textLayerStyle` is used for the export, so the output matches the preview.

```dart
const ChatImageEditorThemeData(
  textLayerStyle: TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w800,
    shadows: [Shadow(blurRadius: 4, color: Color(0x66000000))],
  ),
);
```

### Sizes

| Field | What it sizes | Default |
|---|---|---|
| `iconSize` | Top-bar and toolbar icons. | `24` |
| `captionBorderRadius` | Corners of the caption field. | `BorderRadius.circular(24)` |
| `sendButtonSize` | Diameter of the send and done buttons. | `52` |

### Reading the resolved theme

`ChatImageEditorThemeData.resolve(context, override)` returns a
`ChatImageEditorResolvedTheme` with every field filled in. Inside the editor,
including your [builders](#builders), read it from the scope:

```dart
final theme = ChatImageEditorScope.of(context).theme;
final color = theme.sendButtonColor; // never null
```

## Icons

`ChatImageEditorIcons` takes any widget per icon: an `Icon`, an SVG or an
image. Icons without an explicit color inherit the themed color and
`iconSize` through `IconTheme`.

```dart
ChatImageEditor.open(
  context,
  photo,
  icons: const ChatImageEditorIcons(
    send: Icon(Icons.arrow_upward),
    crop: Icon(Icons.crop),
    textBackground: Icon(Icons.format_paint),
  ),
);
```

| Field | Where it appears | Default |
|---|---|---|
| `close` | Closes the editor (top bar, outside drawing). | `Icons.close` |
| `undo` | Undo button, in the top bar and while drawing. | `Icons.undo` |
| `redo` | Redo button. | `Icons.redo` |
| `draw` | Draw tool button, and the icon on the pen-color swatch while drawing. | `Icons.edit_outlined` |
| `text` | Text tool button. | `Icons.title` |
| `crop` | Crop tool button. | `Icons.crop_rotate` |
| `compress` | Compress tool button. | `Icons.hd_outlined` |
| `rotateLeft` | Rotate a quarter turn counter-clockwise. | `Icons.rotate_left` |
| `rotateRight` | Rotate a quarter turn clockwise. | `Icons.rotate_right` |
| `flipHorizontal` | Mirror left-right. | `Icons.flip` |
| `flipVertical` | Mirror top-bottom. | `Icons.flip`, turned a quarter turn |
| `resetCrop` | Reset crop, rotation and flips. | `Icons.restart_alt` |
| `confirm` | Confirm the crop, at the end of the crop row. | `Icons.check` |
| `cancel` | Cancel the crop, at the start of the crop row. | `Icons.close` |
| `send` | Send button (send mode). | `Icons.send` |
| `done` | Done button (done mode). | `Icons.check` |
| `delete` | Drag-to-delete target. | `Icons.delete_outline` |
| `textBackground` | Cycles the text background style. | `Icons.format_color_fill` |
| `freehand` | Freehand pen shape. | `Icons.gesture` |
| `line` | Line shape. | `Icons.horizontal_rule` |
| `rectangle` | Rectangle shape. | `Icons.crop_square` |
| `circle` | Circle shape. | `Icons.circle_outlined` |
| `arrow` | Arrow shape. | `Icons.north_east` |

Each field has a matching getter that returns your widget or the default,
named with an `Icon` suffix: `closeIcon`, `undoIcon`, `sendIcon`,
`arrowIcon` and so on. Use them in custom builders:

```dart
final icons = ChatImageEditorScope.of(context).icons;
IconButton(onPressed: onSend, icon: icons.sendIcon);
```

## Strings

`ChatImageEditorStrings` holds every user-facing string, tooltip and
semantics label, with English defaults. Pass a translated instance to
localize the editor.

```dart
ChatImageEditorStrings stringsFor(Locale locale) {
  switch (locale.languageCode) {
    case 'fr':
      return const ChatImageEditorStrings(
        captionHint: 'Ajouter une légende…',
        send: 'Envoyer',
        draw: 'Dessiner',
        text: 'Texte',
        crop: 'Recadrer et pivoter',
        compress: "Qualité de l'image",
        cancel: 'Annuler',
        confirm: 'OK',
        done: 'OK',
        apply: 'Appliquer',
        color: 'Couleur',
      );
    default:
      return const ChatImageEditorStrings();
  }
}
```

Then pass the instance for the current locale:

```dart
ChatImageEditor.open(
  context,
  photo,
  strings: stringsFor(Localizations.localeOf(context)),
);
```

If your app uses generated localizations, build the instance in the same
way, filling each field from your localization class.

| Field | Where it's used | Default |
|---|---|---|
| `captionHint` | Caption field hint. | `Add a caption…` |
| `close` | Close button tooltip. | `Close` |
| `undo` | Undo button tooltip. | `Undo` |
| `redo` | Redo button tooltip. | `Redo` |
| `draw` | Draw tool tooltip, and the pen-color swatch's tooltip while drawing. | `Draw` |
| `text` | Text tool tooltip. | `Text` |
| `crop` | Crop tool tooltip. | `Crop and rotate` |
| `compress` | Compress tool tooltip and sheet title. | `Image quality` |
| `rotateLeft` | Rotate-left tooltip. | `Rotate left` |
| `rotateRight` | Rotate-right tooltip. | `Rotate right` |
| `flipHorizontal` | Flip-horizontal tooltip. | `Flip horizontally` |
| `flipVertical` | Flip-vertical tooltip. | `Flip vertically` |
| `resetCrop` | Reset-crop tooltip. | `Reset` |
| `freeAspectRatio` | Label of the free (unconstrained) crop preset. | `Free` |
| `confirm` | Crop confirm tooltip. | `Done` |
| `cancel` | Crop cancel tooltip. | `Cancel` |
| `send` | Send button tooltip. | `Send` |
| `done` | Done button tooltip (done mode), and the **Done** pill that ends drawing and text entry. | `Done` |
| `delete` | Delete target semantics label. | `Delete` |
| `textBackground` | Text background button tooltip. | `Text background` |
| `strokeWidth` | Brush size slider semantics label. | `Brush size` |
| `freehand` | Freehand shape tooltip. | `Pen` |
| `line` | Line shape tooltip. | `Line` |
| `rectangle` | Rectangle shape tooltip. | `Rectangle` |
| `circle` | Circle shape tooltip. | `Circle` |
| `arrow` | Arrow shape tooltip. | `Arrow` |
| `qualityLabel` | Label of the quality row in the compress sheet, and the slider's semantics label. | `Quality` |
| `originalSizeLabel` | Label before the original file size. | `Original` |
| `estimatedSizeLabel` | Label before the estimated file size. | `Estimated size` |
| `estimatingSize` | Shown while the size estimate is computed. | `Calculating…` |
| `discardTitle` | Discard dialog title. | `Discard changes?` |
| `discardMessage` | Discard dialog message. | `Your edits to this image will be lost.` |
| `discardConfirm` | Discard dialog confirm button. | `Discard` |
| `keepEditing` | Discard dialog cancel button. | `Keep editing` |
| `loadFailed` | Shown when the source image can't be decoded. | `Couldn't open this image.` |
| `exportFailed` | Shown when export fails. | `Couldn't prepare this image. Please try again.` |
| `color` | Semantics label of the color slider. | `Color` |
| `apply` | Compress sheet button that keeps the chosen quality. | `Apply` |
| `formatBytes` | Formats file sizes in the compress sheet. | `ChatImageEditorStrings.defaultFormatBytes` |
| `colorLabel` | Screen reader name of the palette color closest to the color slider's position. | `ChatImageEditorStrings.defaultColorLabel` (`Color 3 of 10`) |
| `formatQuality` | Describes the quality in the compress sheet. | `ChatImageEditorStrings.defaultFormatQuality` (`Low · 40`, `Medium · 70`, `High · 90`) |

### Formatting file sizes

`formatBytes` is a `String Function(int bytes)`. The default prints `B`, `KB`
or `MB` with one decimal, using 1024 as the base. Replace it to match your
locale or units:

```dart
ChatImageEditorStrings(
  formatBytes: (bytes) => '${(bytes / 1000).toStringAsFixed(0)} kB',
);
```

### Naming colors for screen readers

Screen readers see the color slider as a slider labelled `color` that steps
through the palette: increasing or decreasing it moves to the next or
previous palette color. Its value is `colorLabel`, a
`String Function(Color color, int index, int count)` that names the palette
color closest to the slider's position. `index` is zero-based. The default
reads `Color 3 of 10`. Translate it, or name your palette's colors:

```dart
ChatImageEditorStrings(
  color: 'Couleur',
  colorLabel: (color, index, count) => 'Couleur ${index + 1} sur $count',
);
```

### Describing quality

`formatQuality` is a `String Function(int quality)` that describes the JPEG
quality in the compress sheet. The default names a tier and the value:
`Low · 40` (up to 40), `Medium · 70` (41 to 75) and `High · 90` (above 75).
Translate the tiers or show a percentage instead:

```dart
ChatImageEditorStrings(
  formatQuality: (quality) => switch (quality) {
    <= 40 => 'Basse · $quality',
    <= 75 => 'Moyenne · $quality',
    _ => 'Haute · $quality',
  },
);
```

## Caption field

In send mode the bottom bar shows a caption `TextFormField` inside a `Form`,
with the recipient chip (`header`) and the send button in a row below it.
`CaptionFieldConfig` maps onto the matching `TextFormField` parameters. Leave
a field `null` for the themed default.

```dart
final captionController = TextEditingController(text: 'Look at this!');

ChatImageEditor.open(
  context,
  photo,
  captionField: CaptionFieldConfig(
    controller: captionController,
    maxLength: 280,
    maxLines: 3,
    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
    validator: (value) =>
        (value ?? '').trim().isEmpty ? 'Please add a caption' : null,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    header: const Text('Sending to Family'),
  ),
);
```

`FilteringTextInputFormatter` comes from `package:flutter/services.dart`.

| Option | Type | Default | What it does |
|---|---|---|---|
| `enabled` | `bool` | `true` | Shows the caption field. When `false`, only the send button shows (no field, no header chip). |
| `controller` | `TextEditingController?` | `null` | Controls the caption text. When `null`, the editor owns one. |
| `focusNode` | `FocusNode?` | `null` | Focus node for the field. |
| `initialValue` | `String?` | `null` | Starting caption when no `controller` is given. Don't pass both. |
| `decoration` | `InputDecoration?` | Rounded pill | Replaces the default decoration. If its `hintText` is `null`, `strings.captionHint` is used. |
| `style` | `TextStyle?` | Theme `captionStyle` | Style of the typed text, merged onto the theme's `captionStyle`: it overrides only what it sets. |
| `cursorColor` | `Color?` | Theme `primaryColor` | Cursor color. |
| `minLines` | `int?` | `1` | Minimum visible lines. |
| `maxLines` | `int?` | `5` | Maximum visible lines before the field scrolls. |
| `maxLength` | `int?` | `null` | Maximum number of characters. `null` means no limit. |
| `keyboardType` | `TextInputType` | `TextInputType.multiline` | Keyboard type. |
| `textInputAction` | `TextInputAction` | `TextInputAction.newline` | Action button on the keyboard. |
| `textCapitalization` | `TextCapitalization` | `TextCapitalization.sentences` | Automatic capitalization. |
| `inputFormatters` | `List<TextInputFormatter>?` | `null` | Formatters applied while typing. |
| `validator` | `FormFieldValidator<String>?` | `null` | Validates the caption. Sending is blocked while it returns an error. |
| `autovalidateMode` | `AutovalidateMode?` | `null` | When to run the validator. |
| `onChanged` | `ValueChanged<String>?` | `null` | Called on every change. |
| `autofocus` | `bool` | `false` | Focuses the field when the editor opens. It doesn't take focus again when the field reappears after a tool closes. |
| `header` | `Widget?` | `null` | Shown in a translucent chip below the field, beside the send button, such as the recipient's name. Long text is cut to one line with an ellipsis. |

The caption arrives trimmed in `ChatImageEditorResult.caption`. A typed
caption counts as unsaved work for the discard prompt.

The default pill uses the theme's `captionFillColor`, `captionHintColor` and
`captionBorderRadius`. To keep that look but change one thing, pass your own
`decoration` with the same colors:

```dart
const CaptionFieldConfig(
  decoration: InputDecoration(
    hintText: 'Say something…',
    filled: true,
    fillColor: Color(0x8A000000), // the default: black, 54%
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
  ),
);
```

## Builders

`ChatImageEditorBuilders` replaces parts of the UI. Anything left `null`
uses the built-in, themed widget.

| Builder | Type | Replaces |
|---|---|---|
| `topBar` | `EditorRegionBuilder?` | The top bar: close, undo/redo and tool buttons, including the morphing pen-mode bar (**Done** pill, undo, pen-color swatch). |
| `bottomBar` | `EditorRegionBuilder?` | The caption area: caption field, recipient chip and send button, or the done button. The draw tool's shape picker and brush size slider still show while drawing. |
| `sendButton` | `SendButtonBuilder?` | The send button (send mode). |
| `doneButton` | `SendButtonBuilder?` | The done button (done mode). |
| `loading` | `WidgetBuilder?` | The view shown while the image decodes. |
| `error` | `EditorErrorBuilder?` | The view shown when the image can't be decoded. |
| `confirmDiscard` | `DiscardConfirmation?` | The platform-adaptive "discard changes?" dialog. |

The typedefs:

```dart
typedef EditorRegionBuilder =
    Widget Function(BuildContext context, ChatImageEditorController controller);
typedef SendButtonBuilder =
    Widget Function(BuildContext context, SendButtonDetails details);
typedef EditorErrorBuilder =
    Widget Function(BuildContext context, Object error);
typedef DiscardConfirmation = Future<bool> Function(BuildContext context);
```

Builders run inside the editor, so `ChatImageEditorScope.of(context)` gives
you everything the built-in widgets use:

| Scope member | What it is |
|---|---|
| `controller` | The editor's `ChatImageEditorController`. |
| `theme` | The `ChatImageEditorResolvedTheme`, every value filled in. |
| `icons` | The `ChatImageEditorIcons` in use. |
| `strings` | The `ChatImageEditorStrings` in use. |
| `config` | The `ChatImageEditorConfig` in use. |
| `captionField` | The `CaptionFieldConfig` in use. |
| `builders` | The `ChatImageEditorBuilders` in use. |

### Send and done buttons

`SendButtonDetails` tells your button what to do and how to look:

| Field | What it is |
|---|---|
| `onPressed` | Exports and returns the result. `null` while disabled or busy. |
| `onLongPress` | The long-press action, when `onSendLongPress` is set. |
| `enabled` | Whether sending is allowed right now. |
| `busy` | Whether an export is running. |

```dart
ChatImageEditorBuilders(
  sendButton: (context, details) {
    final scope = ChatImageEditorScope.of(context);
    return FilledButton.icon(
      onPressed: details.onPressed,
      onLongPress: details.onLongPress,
      icon: details.busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : scope.icons.sendIcon,
      label: Text(scope.strings.send),
    );
  },
  doneButton: (context, details) => TextButton(
    onPressed: details.onPressed,
    child: const Text('Use photo'),
  ),
);
```

### Top and bottom bars

Region builders get the controller, so a custom bar can drive the editor.
Listen to the controller to rebuild when its state changes:

```dart
ChatImageEditorBuilders(
  topBar: (context, controller) {
    final scope = ChatImageEditorScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        children: [
          IconButton(
            tooltip: scope.strings.undo,
            onPressed: controller.canUndo ? controller.undo : null,
            icon: scope.icons.undoIcon,
          ),
          const Spacer(),
          for (final tool in scope.config.tools)
            IconButton(
              isSelected: controller.activeTool == tool,
              onPressed: () => controller.selectTool(tool),
              icon: switch (tool) {
                EditorTool.draw => scope.icons.drawIcon,
                EditorTool.text => scope.icons.textIcon,
                EditorTool.crop => scope.icons.cropIcon,
                EditorTool.compress => scope.icons.compressIcon,
                EditorTool.none => const SizedBox.shrink(),
              },
            ),
        ],
      ),
    );
  },
);
```

A custom `topBar` replaces the built-in close, undo/redo and tool buttons in
every mode, including while drawing, so include whatever your users need.
The built-in bar morphs while the draw tool is open; a custom one can do the
same by checking `controller.activeTool == EditorTool.draw` and offering a
way out with `controller.closeTool()`.

A custom `bottomBar` replaces the caption field and the send button, so it
has to finish on its own: call `controller.export(caption: …)` and deliver
the result yourself. This fits best when you [embed](#embedding) the widget
and control the page around it.

### Loading, error and discard

```dart
ChatImageEditorBuilders(
  loading: (context) => const Center(child: Text('Opening…')),
  error: (context, error) => Center(child: Text('Oops: $error')),
  confirmDiscard: (context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Throw away your edits?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return discard ?? false;
  },
);
```

`confirmDiscard` runs only when `config.confirmDiscard` is `true` (the
default) and there are unsaved edits or a caption. Return `true` to close the
editor. It runs for the close button and for the system back gesture once no
tool or text entry is open (back first closes those).

The built-in dialog is platform-adaptive: a Cupertino alert on iOS and
macOS, a Material dialog elsewhere. It uses `discardTitle`,
`discardMessage`, `discardConfirm` and `keepEditing` from the strings, so
most apps only need to translate those. Supply `confirmDiscard` when you want
a different look, such as your app's own dialog or a bottom sheet.

## Send button behaviour

Two parameters change how the send button behaves:

- `sendEnabled`: a `ValueListenable<bool>`. The send button is disabled
  while it's `false`. `null` means always enabled.
- `onSendLongPress`: a `SendLongPressCallback`, called on a long press of
  the send button. `null` disables long press.

```dart
typedef ExportCallback = Future<ChatImageEditorResult?> Function();
typedef SendLongPressCallback =
    Future<bool> Function(BuildContext context, ExportCallback export);
```

The callback gets an `export` function that renders the image on demand and
returns the result, or `null` on failure. Return `true` to close the editor
or `false` to stay. Handle the result inside the callback.

```dart
final canSend = ValueNotifier<bool>(false); // Flip to true when ready.

ChatImageEditor.open(
  context,
  photo,
  sendEnabled: canSend,
  onSendLongPress: (context, export) async {
    final silent = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => ListTile(
        title: const Text('Send without sound'),
        onTap: () => Navigator.of(context).pop(true),
      ),
    );
    if (silent != true) return false;
    final result = await export();
    if (result == null) return false;
    sendSilently(result); // Your code.
    return true;
  },
);
```

## Behaviour

`ChatImageEditorConfig` switches features on and off. Colors, icons and
text are not here; they live in the theme, icons and strings.

| Option | Default | What it does |
|---|---|---|
| `mode` | `ChatImageEditorMode.send` | `send`: caption plus send button. `done`: a single done button, no caption. |
| `tools` | crop, compress, text, draw | Tools in the top bar, in this order. Tools left out are hidden. |
| `shapes` | all `ShapeType` values | Shapes offered by the draw tool, in this order. The draw tool starts on freehand if it's offered, otherwise on the first shape. With one shape, no picker shows. |
| `cropAspectRatios` | `1`, `4/3`, `3/4`, `16/9`, `9/16` | Crop presets (width / height) shown next to free cropping. Empty hides them. |
| `export` | `ExportOptions()` | How the result is encoded. See [Export options](#export-options). |
| `previewMaxLongEdge` | `2048` | Longest side, in pixels, of the image decoded for editing. Affects preview sharpness and memory only. |
| `defaultStrokeWidth` | `0.008` | Starting brush size, as a fraction of the image's shortest side. |
| `minStrokeWidth` | `0.002` | Smallest brush size the slider allows. |
| `maxStrokeWidth` | `0.03` | Largest brush size the slider allows. Set it equal to `minStrokeWidth` to hide the slider. |
| `defaultFontSize` | `0.06` | Starting text size, as a fraction of the image's shortest side. |
| `minFontSize` | `0.02` | Smallest text size pinching allows. |
| `maxFontSize` | `0.25` | Largest text size pinching allows. |
| `confirmDiscard` | `true` | Asks before discarding unsaved edits or a caption on close. |
| `enableZoom` | `true` | Allows pinch-to-zoom while no tool is open. |
| `enableHaptics` | `true` | Light haptic feedback on snaps and the delete target. |
| `showUndoRedo` | `true` | Shows undo and redo buttons in the top bar, and undo in the pen-mode bar. |
| `hideSystemBarsWhileDrawing` | `false` | Opt-in. Hides the system status and navigation bars while the draw tool is open, so the whole screen is canvas. |

The tools are `EditorTool.draw`, `text`, `crop` and `compress`. The shapes
are `ShapeType.freehand`, `line`, `rectangle`, `circle` and `arrow`.

Brush and text sizes are relative to the image, so a stroke looks the same
on a small preview and in a full-resolution export.

```dart
const config = ChatImageEditorConfig(
  tools: [EditorTool.draw, EditorTool.text],
  shapes: [ShapeType.freehand, ShapeType.arrow, ShapeType.rectangle],
  cropAspectRatios: [],
  defaultStrokeWidth: 0.012,
  showUndoRedo: true,
  enableZoom: false,
);

// Tweak an existing config.
final avatarConfig = config.copyWith(
  mode: ChatImageEditorMode.done,
  tools: [EditorTool.crop],
  cropAspectRatios: [1],
);
```

## Export options

`ExportOptions` (set through `ChatImageEditorConfig.export`) decides how the
edited image becomes bytes. Export always re-renders from the source bytes,
not from the preview.

| Option | Default | What it does |
|---|---|---|
| `format` | `ExportFormat.jpeg` | `jpeg`: small files, no transparency. `png`: lossless, keeps transparency, larger files. |
| `quality` | `90` | JPEG quality, 1–100, used when the user didn't pick one in the compress tool. |
| `maxLongEdge` | `4096` | Longest side of the output in pixels. Larger results are scaled down proportionally. `null` keeps full resolution. |
| `maxBytes` | `null` | Target maximum file size in bytes. `null` means no limit. |
| `minQuality` | `30` | Lowest JPEG quality the `maxBytes` search may use. |
| `encoder` | `null` | Encoder to use. `null` uses the built-in `DartImageEncoder`. |
| `backgroundColor` | White | Fills transparent pixels for JPEG output, which has no alpha channel. |

### Fitting a size limit

With `maxBytes` set, JPEG quality steps down in steps of 10, never below
`minQuality`, until the file fits: from quality 90 with the default
`minQuality` 30 it tries 80, 70, 60, 50, 40 and 30. If it still doesn't
fit, the result holds the smallest attempt and `exceedsMaxBytes` is `true`.
Lowering `maxLongEdge` too makes fitting much easier:

```dart
final result = await ChatImageEditor.open(
  context,
  photo,
  config: const ChatImageEditorConfig(
    export: ExportOptions(maxBytes: 300 * 1024, maxLongEdge: 1600),
  ),
);
if (result != null && result.exceedsMaxBytes) {
  // Still too big: warn the user or upload anyway.
}
```

### The compress sheet

The compress tool lets the user pick the quality: a slider from 10 to 100 in
steps of 10, labelled with `strings.formatQuality` (`Low · 40`,
`Medium · 70`, `High · 90`), the original size and a live estimate of the new
size. The slider is a draft until the user taps **Apply**, which records the
quality as one undo step; tapping outside the sheet closes it without
changing anything. The applied quality replaces `ExportOptions.quality`, and
a `maxBytes` search starts from it.

Quality applies to JPEG only. If you export PNG you may want to remove
`EditorTool.compress` from `config.tools`.

### Custom encoder

Implement `ImageEncoder` to plug in your own encoder, for example a native
one. `encode` receives an `RgbaImage`: straight (not premultiplied) RGBA, 8
bits per channel, row by row, `width * height * 4` bytes.

```dart
class LoggingEncoder implements ImageEncoder {
  const LoggingEncoder();

  static const ImageEncoder _inner = DartImageEncoder();

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) async {
    final watch = Stopwatch()..start();
    final bytes = await _inner.encode(image, format: format, quality: quality);
    debugPrint('Encoded ${image.width}x${image.height} in ${watch.elapsed}');
    return bytes;
  }
}

const config = ChatImageEditorConfig(
  export: ExportOptions(encoder: LoggingEncoder()),
);
```

`DartImageEncoder` is pure Dart. It encodes in a background isolate where
isolates are available and on the main thread on the web.

## Controller

`ChatImageEditorController` holds the editor state and every editing action.
The editor creates one automatically. Create your own to drive the editor
from code, read its state, or build a fully custom UI with
[builders](#builders).

```dart
class _EditorPageState extends State<EditorPage> {
  final _controller = ChatImageEditorController();

  // Rotation happens in a crop session, kept as one undo step.
  void _rotate() {
    if (_controller.activeTool != EditorTool.crop) {
      _controller.selectTool(EditorTool.crop);
    }
    _controller.rotateRight();
    _controller.confirmCrop();
  }

  @override
  void dispose() {
    _controller.dispose(); // Yours to dispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ChatImageEditor(image: widget.photo, controller: _controller),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Row(
            children: [
              TextButton(
                onPressed: _controller.canUndo ? _controller.undo : null,
                child: const Text('Undo'),
              ),
              TextButton(onPressed: _rotate, child: const Text('Rotate')),
              TextButton(
                onPressed: () => _controller.selectTool(EditorTool.draw),
                child: const Text('Draw'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

The most useful members:

| Area | Members |
|---|---|
| Loading | `loadStatus`, `loadError`, `originalSize`, `load(bytes)` |
| History | `value`, `hasChanges`, `canUndo`, `canRedo`, `undo()`, `redo()`, `clearEdits()` |
| Tools | `activeTool`, `selectTool(tool)`, `closeTool()` |
| Draw | `shapeType`, `setShapeType(type)`, `drawColor`, `setDrawColor(color)`, `strokeWidth`, `setStrokeWidth(width)` |
| Text | `textColor`, `setTextColor(color)`, `textBackground`, `setTextBackground(style)`, `cycleTextBackground()`, `addText()`, `editText(id)`, `deleteText(id)` |
| Crop | `cropAspectRatio`, `setCropAspectRatio(ratio)`, `rotateLeft()`, `rotateRight()`, `flipHorizontal()`, `flipVertical()`, `resetCrop()`, `confirmCrop()`, `cancelCrop()` |
| Compress | `quality`, `setQuality(quality)`, `commitQuality()`, `estimateSize(quality)` |
| Export | `isExporting`, `export(caption: …)`, `textLayerStyle` |

A few things to know:

- Rotating, flipping and cropping happen in a crop session. Open it with
  `selectTool(EditorTool.crop)` and keep the changes with `confirmCrop()`.
  Leaving the crop tool any other way cancels the session. Called with no
  session open, each of these calls is recorded as its own undo step.
- The editor sets `textLayerStyle` from the resolved theme, so exported text
  matches the preview. Set it yourself only when you export with a
  controller that isn't attached to a `ChatImageEditor`.
- One undo step is recorded per finished action: a stroke, a text edit, a
  text move, a deleted text, a confirmed crop or a quality change.
- `export` returns `null` on failure or when an export is already running.
- Every result carries the `ImageEditValue` that produced it in
  `result.edits`.

The full API is in the
[API reference](https://pub.dev/documentation/chat_image_editor/latest/chat_image_editor/ChatImageEditorController-class.html).

## Embedding

`ChatImageEditor.open` pushes a full-screen route and returns the result. To
put the editor in your own route or layout, use the widget:

```dart
ChatImageEditor(
  image: photo,
  onComplete: (result) => Navigator.of(context).pop(result),
  onCancel: () => Navigator.of(context).pop(),
);
```

- `onComplete` is called with the result after a successful send or done.
  When `null`, the editor pops its route with the result.
- `onCancel` is called when the user closes the editor, after any discard
  confirmation. When `null`, the editor pops its route with `null`.

The editor is designed to fill the screen. Give it the full size of the page
for the best result.
