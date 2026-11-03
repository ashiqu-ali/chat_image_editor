// Host side of the frame performance test. Run from example/:
//
//   fvm flutter drive --driver=test_driver/perf_driver.dart \
//     --target=integration_test/editor_performance_test.dart --profile -d <device>
//
// Each `watchPerformance` report is written to
// build/<reportKey>.timeline_summary.json (the folder follows
// FLUTTER_TEST_OUTPUTS_DIR when that is set).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;
      for (final MapEntry(:key, :value) in data.entries) {
        if (value is! Map<String, dynamic>) continue;
        await writeResponseData(
          value,
          testOutputFilename: '$key.timeline_summary',
        );
      }
    },
  );
}
