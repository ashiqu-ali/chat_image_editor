import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('tools', () {
    testWidgets('every tool fits a small phone screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await pumpReadyEditor(tester);

      for (final tool in <String>['Draw', 'Crop and rotate', 'Image quality']) {
        await tester.tap(find.byTooltip(tool));
        await tester.pumpAndSettle();
        controller.closeTool();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Text'));
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
