import 'dart:ui' as ui;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const Size original = Size(400, 300);
const Rect crop = Rect.fromLTRB(0.1, 0.2, 0.7, 0.9);

const List<Offset> samplePoints = <Offset>[
  Offset.zero,
  Offset(1, 0),
  Offset(0, 1),
  Offset(1, 1),
  Offset(0.5, 0.5),
  Offset(0.25, 0.75),
  Offset(0.9, 0.13),
  Offset(-0.2, 1.3),
];

const List<Offset> unitCorners = <Offset>[
  Offset.zero,
  Offset(1, 0),
  Offset(0, 1),
  Offset(1, 1),
];

void main() {
  group('transformedSize', () {
    test('keeps the size for even turns and swaps it for odd turns', () {
      expect(ImageGeometry.transformedSize(original, 0), original);
      expect(ImageGeometry.transformedSize(original, 1), const Size(300, 400));
      expect(ImageGeometry.transformedSize(original, 2), original);
      expect(ImageGeometry.transformedSize(original, 3), const Size(300, 400));
      expect(ImageGeometry.transformedSize(original, 5), const Size(300, 400));
    });
  });

  group('cropRectPx', () {
    test('is the whole transformed image without a crop', () {
      expect(
        ImageGeometry.cropRectPx(const Size(300, 400), null),
        const Rect.fromLTWH(0, 0, 300, 400),
      );
    });

    test('scales the normalized crop to pixels', () {
      expect(
        ImageGeometry.cropRectPx(
          const Size(300, 400),
          const Rect.fromLTRB(0.5, 0.25, 1, 0.75),
        ),
        const Rect.fromLTRB(150, 100, 300, 300),
      );
    });
  });

  group('outputSize', () {
    test('swaps width and height for odd quarter turns', () {
      expect(
        ImageGeometry.outputSize(original, ImageEditValue.empty),
        original,
      );
      expect(
        ImageGeometry.outputSize(
          original,
          const ImageEditValue(quarterTurns: 1),
        ),
        const Size(300, 400),
      );
      expect(
        ImageGeometry.outputSize(
          original,
          const ImageEditValue(quarterTurns: 2, flipX: true),
        ),
        original,
      );
    });

    test('applies the crop after the rotation', () {
      expect(
        ImageGeometry.outputSize(
          original,
          const ImageEditValue(
            quarterTurns: 1,
            crop: Rect.fromLTRB(0.5, 0, 1, 0.5),
          ),
        ),
        const Size(150, 200),
      );
    });
  });

  group('round trips', () {
    for (final cropRect in <Rect?>[null, crop]) {
      test('viewToOriginal inverts originalToView for every orientation '
          '(crop: $cropRect)', () {
        for (final value in allOrientations(crop: cropRect)) {
          for (final p in samplePoints) {
            final view = ImageGeometry.originalToView(p, original, value);
            expect(
              ImageGeometry.viewToOriginal(view, original, value),
              offsetCloseTo(p),
              reason: '${describeTransform(value)} point $p',
            );
            final back = ImageGeometry.viewToOriginal(p, original, value);
            expect(
              ImageGeometry.originalToView(back, original, value),
              offsetCloseTo(p),
              reason: '${describeTransform(value)} view point $p',
            );
          }
        }
      });
    }

    test('works before the image size is known', () {
      for (final value in allOrientations(crop: crop)) {
        for (final p in samplePoints) {
          final view = ImageGeometry.originalToView(p, Size.zero, value);
          expect(
            ImageGeometry.viewToOriginal(view, Size.zero, value),
            offsetCloseTo(p),
            reason: describeTransform(value),
          );
        }
      }
    });
  });

  group('corners', () {
    test('map to corners for every orientation without a crop', () {
      for (final value in allOrientations()) {
        final mapped = <Offset>[
          for (final c in unitCorners)
            ImageGeometry.originalToView(c, original, value),
        ];
        for (final corner in unitCorners) {
          expect(
            mapped.where((Offset m) => (m - corner).distance < 1e-9),
            hasLength(1),
            reason: '${describeTransform(value)} corner $corner',
          );
        }
      }
    });

    test('follow a clockwise quarter turn', () {
      const value = ImageEditValue(quarterTurns: 1);
      Offset map(Offset p) => ImageGeometry.originalToView(p, original, value);
      expect(map(Offset.zero), offsetCloseTo(const Offset(1, 0)));
      expect(map(const Offset(1, 0)), offsetCloseTo(const Offset(1, 1)));
      expect(map(const Offset(1, 1)), offsetCloseTo(const Offset(0, 1)));
      expect(map(const Offset(0, 1)), offsetCloseTo(Offset.zero));
    });

    test('follow a half turn and a counter-clockwise quarter turn', () {
      expect(
        ImageGeometry.originalToView(
          Offset.zero,
          original,
          const ImageEditValue(quarterTurns: 2),
        ),
        offsetCloseTo(const Offset(1, 1)),
      );
      expect(
        ImageGeometry.originalToView(
          Offset.zero,
          original,
          const ImageEditValue(quarterTurns: 3),
        ),
        offsetCloseTo(const Offset(0, 1)),
      );
    });

    test('follow flips', () {
      expect(
        ImageGeometry.originalToView(
          const Offset(0.2, 0.3),
          original,
          const ImageEditValue(flipX: true),
        ),
        offsetCloseTo(const Offset(0.8, 0.3)),
      );
      expect(
        ImageGeometry.originalToView(
          const Offset(0.2, 0.3),
          original,
          const ImageEditValue(flipY: true),
        ),
        offsetCloseTo(const Offset(0.2, 0.7)),
      );
    });

    test('flip before rotate: flipX then a quarter turn', () {
      // Flipped, the top-left becomes the top-right; a clockwise quarter
      // turn then takes it to the bottom-right.
      expect(
        ImageGeometry.originalToView(
          Offset.zero,
          original,
          const ImageEditValue(quarterTurns: 1, flipX: true),
        ),
        offsetCloseTo(const Offset(1, 1)),
      );
    });

    test('both flips equal a half turn', () {
      for (final p in samplePoints) {
        expect(
          ImageGeometry.originalToView(
            p,
            original,
            const ImageEditValue(flipX: true, flipY: true),
          ),
          offsetCloseTo(
            ImageGeometry.originalToView(
              p,
              original,
              const ImageEditValue(quarterTurns: 2),
            ),
          ),
        );
      }
    });

    test('crop corners map to view corners', () {
      const value = ImageEditValue(crop: Rect.fromLTRB(0.25, 0.5, 0.75, 1));
      expect(
        ImageGeometry.originalToView(const Offset(0.25, 0.5), original, value),
        offsetCloseTo(Offset.zero),
      );
      expect(
        ImageGeometry.originalToView(const Offset(0.75, 1), original, value),
        offsetCloseTo(const Offset(1, 1)),
      );
    });

    test('crop corners map to view corners after a rotation', () {
      // 400×300 turned clockwise is 300×400; the crop is its top-right
      // quarter: transformed pixels (150, 0)–(300, 200).
      const value = ImageEditValue(
        quarterTurns: 1,
        crop: Rect.fromLTRB(0.5, 0, 1, 0.5),
      );
      expect(
        ImageGeometry.viewToOriginal(Offset.zero, original, value),
        offsetCloseTo(const Offset(0, 0.5)),
      );
      expect(
        ImageGeometry.viewToOriginal(const Offset(1, 1), original, value),
        offsetCloseTo(const Offset(0.5, 0)),
      );
      expect(
        ImageGeometry.originalToView(Offset.zero, original, value),
        offsetCloseTo(const Offset(1, 0)),
      );
    });
  });

  group('originalToOutput', () {
    test('agrees with originalToView for every orientation', () {
      for (final cropRect in <Rect?>[null, crop]) {
        for (final value in allOrientations(crop: cropRect)) {
          final matrix = ImageGeometry.originalToOutput(original, value);
          final output = ImageGeometry.outputSize(original, value);
          for (final p in samplePoints) {
            final px = MatrixUtils.transformPoint(
              matrix,
              Offset(p.dx * original.width, p.dy * original.height),
            );
            final view = ImageGeometry.originalToView(p, original, value);
            expect(
              px,
              offsetCloseTo(
                Offset(view.dx * output.width, view.dy * output.height),
                1e-6,
              ),
              reason: describeTransform(value),
            );
          }
        }
      }
    });

    test('maps the original image onto the output rect without a crop', () {
      for (final value in allOrientations()) {
        final bounds = MatrixUtils.transformRect(
          ImageGeometry.originalToOutput(original, value),
          Offset.zero & original,
        );
        expect(
          bounds,
          rectCloseTo(
            Offset.zero & ImageGeometry.outputSize(original, value),
            1e-6,
          ),
          reason: describeTransform(value),
        );
      }
    });

    test('applyOriginalToOutput sets the same matrix on a canvas', () {
      const value = ImageEditValue(
        quarterTurns: 3,
        flipY: true,
        crop: Rect.fromLTRB(0.1, 0.1, 0.6, 0.8),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      ImageGeometry.applyOriginalToOutput(canvas, original, value);
      final expected = ImageGeometry.originalToOutput(original, value).storage;
      final actual = canvas.getTransform();
      for (var i = 0; i < 16; i++) {
        expect(actual[i], closeTo(expected[i], 1e-9));
      }
      recorder.endRecording().dispose();
    });
  });

  group('fitRect', () {
    test('fits wide content to the bounds width, centered', () {
      expect(
        ImageGeometry.fitRect(
          const Size(200, 100),
          const Rect.fromLTWH(0, 0, 100, 100),
        ),
        const Rect.fromLTRB(0, 25, 100, 75),
      );
    });

    test('fits tall content to the bounds height, centered', () {
      expect(
        ImageGeometry.fitRect(
          const Size(100, 200),
          const Rect.fromLTWH(10, 10, 100, 100),
        ),
        const Rect.fromLTRB(35, 10, 85, 110),
      );
    });

    test('scales small content up', () {
      expect(
        ImageGeometry.fitRect(
          const Size(4, 3),
          const Rect.fromLTWH(0, 0, 400, 600),
        ),
        const Rect.fromLTRB(0, 150, 400, 450),
      );
    });

    test('returns an empty rect at the center for empty content', () {
      final rect = ImageGeometry.fitRect(
        Size.zero,
        const Rect.fromLTWH(0, 0, 100, 50),
      );
      expect(rect.isEmpty, isTrue);
      expect(rect.center, const Offset(50, 25));
    });
  });
}
