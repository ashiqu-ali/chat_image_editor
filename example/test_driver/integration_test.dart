// Host side of integration tests that only report pass or fail, such as
// integration_test/demo_recording_test.dart. Run from example/:
//
//   fvm flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_recording_test.dart -d <device>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(responseDataCallback: null);
