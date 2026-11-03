import 'package:chat_image_editor_example/src/sample_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the sample image encodes as PNG', (tester) async {
    final bytes = await tester.runAsync(
      () => generateSampleImage(size: const Size(64, 48)),
    );

    expect(bytes, isNotNull);
    // PNG signature: 0x89 'P' 'N' 'G'.
    expect(bytes!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });
}
