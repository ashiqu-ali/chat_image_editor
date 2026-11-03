import 'package:flutter/material.dart';

import '../demos/demo.dart';

/// A list tile that opens one demo.
class DemoTile extends StatelessWidget {
  /// Creates a tile for [demo].
  const DemoTile({
    super.key,
    required this.demo,
    required this.onTap,
    this.preparing = false,
  });

  /// The demo to open.
  final EditorDemo demo;

  /// Opens the demo. `null` disables the tile.
  final VoidCallback? onTap;

  /// Shows a spinner while the image is being prepared.
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(demo.icon),
        ),
        title: Text(demo.title),
        subtitle: Text(demo.description),
        trailing: preparing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
