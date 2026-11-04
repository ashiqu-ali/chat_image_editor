import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('compress mode', () {
    testWidgets('compress: shows sizes and commits on close', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Image quality'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.compress);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Estimated size'), findsOneWidget);
      expect(find.text('Calculating…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await pumpUntil(
        tester,
        () => find.text('Calculating…').evaluate().isEmpty,
      );

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
    });
  });
}
