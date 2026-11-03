import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/geometry/affine_2d.dart';
import 'package:chat_image_editor/src/core/geometry/edit_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const Size original = Size(400, 300);

void main() {
  group('Affine2D', () {
    test('composes right to left', () {
      const translate = Affine2D.translation(10, 0);
      const scale = Affine2D.scale(2, 3);
      expect(
        (translate * scale).apply(const Offset(1, 1)),
        const Offset(12, 3),
      );
      expect(
        (scale * translate).apply(const Offset(1, 1)),
        const Offset(22, 3),
      );
    });

    test('inverse undoes the transform', () {
      final transform =
          const Affine2D.translation(5, -3) *
          Affine2D.rotation(0.7) *
          const Affine2D.scale(-1, 2);
      const p = Offset(3.5, -8);
      expect(
        transform.inverse().apply(transform.apply(p)),
        offsetCloseTo(p, 1e-9),
      );
    });

    test('quarter-turn rotations are exact', () {
      final quarter = Affine2D.rotation(math.pi / 2);
      expect(quarter.apply(const Offset(1, 0)), const Offset(0, 1));
      expect(quarter.apply(const Offset(0, 1)), const Offset(-1, 0));
    });

    test('matches its Matrix4', () {
      final transform =
          const Affine2D.translation(4, 9) * Affine2D.rotation(1.1);
      const p = Offset(2, 7);
      expect(
        MatrixUtils.transformPoint(transform.toMatrix4(), p),
        offsetCloseTo(transform.apply(p), 1e-9),
      );
      expect(Affine2D.fromMatrix4(transform.toMatrix4()), transform);
    });
  });

  group('uprightText', () {
    for (final cropRect in <Rect?>[
      null,
      const Rect.fromLTRB(0.2, 0.1, 0.9, 0.6),
    ]) {
      test('makes new text read upright for every orientation '
          '(crop: $cropRect)', () {
        for (final value in allOrientations(crop: cropRect)) {
          final upright = EditGeometry.uprightText(value);
          final layer = TextLayer(
            id: 't',
            text: 'Hi',
            position: const Offset(0.3, 0.6),
            fontSize: 0.05,
            color: const Color(0xFFFFFFFF),
            rotation: upright.rotation,
            mirrored: upright.mirrored,
          );
          final localToOutput =
              Affine2D.fromMatrix4(
                ImageGeometry.originalToOutput(original, value),
              ) *
              EditGeometry.textLayerTransform(layer, original);
          expect(
            localToOutput.applyVector(const Offset(1, 0)),
            offsetCloseTo(const Offset(1, 0)),
            reason: '${describeTransform(value)}: local x axis',
          );
          expect(
            localToOutput.applyVector(const Offset(0, 1)),
            offsetCloseTo(const Offset(0, 1)),
            reason: '${describeTransform(value)}: local y axis',
          );
          expect(
            upright.mirrored,
            value.flipX != value.flipY,
            reason: describeTransform(value),
          );
        }
      });
    }

    test('is the identity for an untouched image', () {
      final upright = EditGeometry.uprightText(ImageEditValue.empty);
      expect(upright.rotation, 0);
      expect(upright.mirrored, isFalse);
    });

    test('counter-rotates a clockwise quarter turn', () {
      final upright = EditGeometry.uprightText(
        const ImageEditValue(quarterTurns: 1),
      );
      expect(upright.rotation, closeTo(-math.pi / 2, 1e-12));
      expect(upright.mirrored, isFalse);
    });

    test('keeps the angle in (-pi, pi]', () {
      for (final value in allOrientations()) {
        final rotation = EditGeometry.uprightText(value).rotation;
        expect(rotation, greaterThan(-math.pi));
        expect(rotation, lessThanOrEqualTo(math.pi));
      }
    });
  });

  group('textLayerTransform', () {
    test('puts the local origin at the layer position', () {
      const layer = TextLayer(
        id: 't',
        text: 'x',
        position: Offset(0.25, 0.5),
        fontSize: 0.1,
        color: Color(0xFFFFFFFF),
        rotation: 1.2,
        mirrored: true,
      );
      expect(
        EditGeometry.textLayerTransform(layer, original).apply(Offset.zero),
        offsetCloseTo(const Offset(100, 150)),
      );
    });

    test('mirrors before rotating', () {
      const layer = TextLayer(
        id: 't',
        text: 'x',
        position: Offset.zero,
        fontSize: 0.1,
        color: Color(0xFFFFFFFF),
        rotation: math.pi / 2,
        mirrored: true,
      );
      // Mirror: +x -> -x; then a clockwise quarter turn: -x -> -y.
      expect(
        EditGeometry.textLayerTransform(
          layer,
          original,
        ).applyVector(const Offset(1, 0)),
        offsetCloseTo(const Offset(0, -1)),
      );
    });
  });

  group('screenRotationSign', () {
    test('is negative exactly when the image is shown mirrored', () {
      for (final value in allOrientations()) {
        expect(
          EditGeometry.screenRotationSign(value),
          value.flipX != value.flipY ? -1 : 1,
          reason: describeTransform(value),
        );
      }
    });
  });

  group('crop transforms', () {
    const rect = Rect.fromLTRB(0.1, 0.2, 0.6, 0.9);

    test('four clockwise turns are the identity', () {
      var r = rect;
      for (var i = 0; i < 4; i++) {
        r = EditGeometry.rotateCropClockwise(r);
      }
      expect(r, rect);
    });

    test('clockwise then counter-clockwise is the identity', () {
      expect(
        EditGeometry.rotateCropCounterClockwise(
          EditGeometry.rotateCropClockwise(rect),
        ),
        rect,
      );
    });

    test('mirroring twice is the identity', () {
      expect(
        EditGeometry.mirrorCropHorizontally(
          EditGeometry.mirrorCropHorizontally(rect),
        ),
        rect,
      );
      expect(
        EditGeometry.mirrorCropVertically(
          EditGeometry.mirrorCropVertically(rect),
        ),
        rect,
      );
    });

    test('a turned crop keeps showing the same part of the picture', () {
      for (final value in allOrientations(crop: rect)) {
        final turned = value.copyWith(
          quarterTurns: (value.quarterTurns + 1) % 4,
          crop: EditGeometry.rotateCropClockwise(rect),
        );
        for (final p in const <Offset>[
          Offset.zero,
          Offset(1, 0),
          Offset(0.3, 0.8),
        ]) {
          // A clockwise turn moves view point (u, v) to (1 - v, u).
          expect(
            ImageGeometry.viewToOriginal(
              Offset(1 - p.dy, p.dx),
              original,
              turned,
            ),
            offsetCloseTo(
              ImageGeometry.viewToOriginal(p, original, value),
              1e-9,
            ),
            reason: describeTransform(value),
          );
        }
      }
    });
  });

  group('aspect helpers', () {
    test('normalizedAspect and screenAspect are inverse', () {
      const transformed = Size(300, 400);
      final normalized = EditGeometry.normalizedAspect(16 / 9, transformed);
      final crop = EditGeometry.fitAspect(EditGeometry.fullCrop, normalized);
      expect(
        EditGeometry.screenAspect(crop, transformed),
        closeTo(16 / 9, 1e-6),
      );
    });

    test('fitAspect fits wide ratios to the width and centers them', () {
      final rect = EditGeometry.fitAspect(const Rect.fromLTRB(0, 0, 1, 1), 2);
      expect(rect, rectCloseTo(const Rect.fromLTRB(0, 0.25, 1, 0.75)));
    });

    test('fitAspect fits tall ratios to the height', () {
      final rect = EditGeometry.fitAspect(
        const Rect.fromLTRB(0.2, 0.2, 0.6, 0.4),
        0.5,
      );
      expect(rect, rectCloseTo(const Rect.fromLTRB(0.35, 0.2, 0.45, 0.4)));
    });
  });

  group('constrainCrop', () {
    test('clamps the rect inside the image', () {
      expect(
        EditGeometry.constrainCrop(
          const Rect.fromLTRB(-0.5, 0.2, 0.5, 1.4),
          minSize: 0.05,
        ),
        rectCloseTo(const Rect.fromLTRB(0, 0.2, 0.5, 1)),
      );
    });

    test('normalizes an inverted rect', () {
      expect(
        EditGeometry.constrainCrop(
          const Rect.fromLTRB(0.8, 0.9, 0.2, 0.1),
          minSize: 0.05,
        ),
        rectCloseTo(const Rect.fromLTRB(0.2, 0.1, 0.8, 0.9)),
      );
    });

    test('grows a tiny rect to the minimum size and keeps it inside', () {
      final rect = EditGeometry.constrainCrop(
        const Rect.fromLTRB(0.99, 0.5, 1, 0.51),
        minSize: 0.1,
      );
      expect(rect.width, closeTo(0.1, 1e-9));
      expect(rect.height, closeTo(0.1, 1e-9));
      expect(rect.right, lessThanOrEqualTo(1));
      expect(rect.left, greaterThanOrEqualTo(0));
    });

    test('respects a locked ratio', () {
      final rect = EditGeometry.constrainCrop(
        const Rect.fromLTRB(0.1, 0.1, 0.9, 0.5),
        minSize: 0.05,
        ratio: 1,
      );
      expect(rect.width, closeTo(rect.height, 1e-9));
      expect(rect.center, offsetCloseTo(const Offset(0.5, 0.3), 1e-9));
    });

    test('keeps the ratio while growing to the minimum size', () {
      final rect = EditGeometry.constrainCrop(
        const Rect.fromLTRB(0.5, 0.5, 0.51, 0.51),
        minSize: 0.1,
        ratio: 2,
      );
      expect(rect.width / rect.height, closeTo(2, 1e-6));
      expect(rect.height, greaterThanOrEqualTo(0.1 - 1e-9));
    });

    test('isFullCrop recognises the whole image', () {
      expect(EditGeometry.isFullCrop(EditGeometry.fullCrop), isTrue);
      expect(
        EditGeometry.isFullCrop(const Rect.fromLTRB(0, 0, 1, 0.99)),
        isFalse,
      );
    });
  });
}
