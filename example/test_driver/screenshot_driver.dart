// Saves screenshots taken by integration_test/screenshots_test.dart to the
// package's doc/screenshots/ folder. Run from example/:
//
//   fvm flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() {
  return integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('../doc/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('Saved ${file.path}');
      return true;
    },
  );
}
