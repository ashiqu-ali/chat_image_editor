import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

import 'controller_demo.dart';
import 'custom_theme_demo.dart';
import 'default_demo.dart';
import 'done_mode_demo.dart';
import 'localized_demo.dart';
import 'size_limit_demo.dart';

/// Opens the editor for one demo and completes with the result, or `null`
/// if the user closed it.
typedef DemoLauncher =
    Future<ChatImageEditorResult?> Function(
      BuildContext context,
      Uint8List image,
    );

/// One entry in the home screen's list of demos.
@immutable
class EditorDemo {
  /// Creates a demo entry.
  const EditorDemo({
    required this.title,
    required this.description,
    required this.icon,
    required this.launch,
    this.maxBytes,
  });

  /// Short name shown as the tile title.
  final String title;

  /// What the demo shows.
  final String description;

  /// Tile icon.
  final IconData icon;

  /// Opens the editor.
  final DemoLauncher launch;

  /// The demo's file size limit, shown next to the result's size.
  final int? maxBytes;
}

/// Every demo, in the order they appear on the home screen.
const List<EditorDemo> editorDemos = <EditorDemo>[
  EditorDemo(
    title: 'Default',
    description:
        'No options at all. Colors come from the app theme, so the accent '
        'follows the seed color above.',
    icon: Icons.auto_awesome_outlined,
    launch: openDefaultDemo,
  ),
  EditorDemo(
    title: 'Custom theme',
    description:
        'Overrides colors and the text style, swaps icons and builds its '
        'own send button.',
    icon: Icons.palette_outlined,
    launch: openCustomThemeDemo,
  ),
  EditorDemo(
    title: 'Done mode',
    description: 'No caption, a single done button and lossless PNG output.',
    icon: Icons.check_circle_outline,
    launch: openDoneModeDemo,
  ),
  EditorDemo(
    title: 'Size limit',
    description: 'JPEG kept under 300 KB and 1600 px on the long edge.',
    icon: Icons.compress,
    launch: openSizeLimitDemo,
    maxBytes: sizeLimitBytes,
  ),
  EditorDemo(
    title: 'Localized',
    description: 'Every label and message translated to Spanish.',
    icon: Icons.translate,
    launch: openLocalizedDemo,
  ),
  EditorDemo(
    title: 'Controller',
    description:
        'An external ChatImageEditorController drives the editor from '
        'buttons and exports from code.',
    icon: Icons.gamepad_outlined,
    launch: openControllerDemo,
  ),
];
