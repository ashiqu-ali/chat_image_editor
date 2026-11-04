import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

/// Opens the compress sheet.
Future<void> openCompress(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Image quality'));
  await tester.pump();
}

/// The size estimate's spinner.
final Finder estimateSpinner = find.byType(CircularProgressIndicator);

/// Waits out the debounce, then lets the size estimate finish.
Future<void> settleEstimate(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await pumpUntil(tester, () => estimateSpinner.evaluate().isEmpty);
  expect(estimateSpinner, findsNothing);
}

/// The value shown in the sheet row labelled [label].
Finder rowValue(String label) {
  return find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != label,
    ),
  );
}

/// Taps the quality slider [fraction] of the way along its track.
Future<void> tapSliderAt(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(Slider));
  // The track is inset from the slider's ends by the thumb's overlay.
  const inset = 24.0;
  final x = rect.left + inset + (rect.width - inset * 2) * fraction;
  await tester.tapAt(Offset(x, rect.center.dy));
  await tester.pump();
}

/// The semantics node of the quality slider. Needs semantics enabled.
SemanticsNode qualitySliderSemantics() {
  return find.semantics.byFlag(SemanticsFlag.isSlider).evaluate().single;
}

/// The quality slider's value.
double sliderValue(WidgetTester tester) {
  return tester.widget<Slider>(find.byType(Slider)).value;
}

void main() {
  group('compress mode', () {
    testWidgets('compress: shows the quality, sizes and an apply button', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await openCompress(tester);
      expect(controller.activeTool, EditorTool.compress);
      expect(find.text('Image quality'), findsWidgets);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('High · 90'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(
        rowValue('Original'),
        findsOneWidget,
        reason: 'the original size is shown',
      );
      expect(find.text('Estimated size'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(sliderValue(tester), 90);
    });

    testWidgets('compress: a spinner shows until the estimate is ready', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpReadyEditor(tester);

      await openCompress(tester);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Estimated size'),
            matching: find.byType(Row),
          ),
          matching: estimateSpinner,
        ),
        findsOneWidget,
      );
      // Screen readers hear the row as one item, then the size.
      expect(
        tester.getSemantics(find.text('Estimated size')).label,
        'Estimated size\nCalculating…',
      );
      expect(find.text('Calculating…'), findsNothing);

      await settleEstimate(tester);
      final size = await tester.runAsync(() => controller.estimateSize(90));
      expect(size, isNotNull);
      final formatted = ChatImageEditorStrings.defaultFormatBytes(size!);
      expect(tester.widget<Text>(rowValue('Estimated size')).data, formatted);
      expect(
        tester.getSemantics(find.text('Estimated size')).label,
        'Estimated size\n$formatted',
      );

      // Moving the slider estimates again.
      await tapSliderAt(tester, 0);
      expect(find.text('Low · 10'), findsOneWidget);
      expect(estimateSpinner, findsOneWidget);
      await settleEstimate(tester);
      final low = await tester.runAsync(() => controller.estimateSize(10));
      expect(
        tester.widget<Text>(rowValue('Estimated size')).data,
        ChatImageEditorStrings.defaultFormatBytes(low!),
      );
      semantics.dispose();
    });

    testWidgets('compress: the label names the quality tier', (tester) async {
      final controller = await pumpReadyEditor(tester);
      await openCompress(tester);

      await tapSliderAt(tester, 0);
      expect(find.text('Low · 10'), findsOneWidget);

      await tapSliderAt(tester, 6 / 9);
      expect(find.text('Medium · 70'), findsOneWidget);

      await tapSliderAt(tester, 1);
      expect(find.text('High · 100'), findsOneWidget);

      // Only the draft moved.
      expect(controller.quality, 90);
      await settleEstimate(tester);
    });

    testWidgets('compress: the slider snaps to steps of 10', (tester) async {
      await pumpReadyEditor(tester);
      await openCompress(tester);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 10);
      expect(slider.max, 100);
      expect(slider.divisions, 9);

      for (final fraction in <double>[0.03, 0.21, 0.37, 0.52, 0.68, 0.94]) {
        await tapSliderAt(tester, fraction);
        final value = sliderValue(tester);
        expect(value % 10, 0, reason: 'tapped at $fraction, got $value');
        expect(
          find.text(ChatImageEditorStrings.defaultFormatQuality(value.round())),
          findsOneWidget,
        );
      }

      final start = tester.getCenter(find.byType(Slider));
      await tester.dragFrom(start, const Offset(37, 0));
      await tester.pump();
      expect(sliderValue(tester) % 10, 0);
      await settleEstimate(tester);
    });

    testWidgets('compress: apply keeps the quality as one undo step', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await openCompress(tester);

      await tapSliderAt(tester, 4 / 9);
      expect(find.text('Medium · 50'), findsOneWidget);
      expect(controller.quality, 90);
      expect(controller.canUndo, isFalse);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(find.text('Apply'), findsNothing);
      expect(controller.quality, 50);
      expect(controller.canUndo, isTrue);

      controller.undo();
      await tester.pump();
      expect(controller.quality, 90);
      expect(controller.canUndo, isFalse);

      // The sheet opens on the applied quality.
      controller.redo();
      await openCompress(tester);
      expect(find.text('Medium · 50'), findsOneWidget);
      expect(sliderValue(tester), 50);
      await settleEstimate(tester);
    });

    testWidgets('compress: tapping outside discards the draft', (tester) async {
      final controller = await pumpReadyEditor(tester);
      await openCompress(tester);

      await tapSliderAt(tester, 0);
      expect(find.text('Low · 10'), findsOneWidget);

      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(find.text('Apply'), findsNothing);
      expect(controller.quality, 90);
      expect(controller.value.quality, isNull);
      expect(controller.canUndo, isFalse);

      await openCompress(tester);
      expect(find.text('High · 90'), findsOneWidget);
      await settleEstimate(tester);
    });

    testWidgets('compress: applying an unchanged quality records nothing', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await openCompress(tester);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.quality, isNull);
      expect(controller.canUndo, isFalse);
    });

    testWidgets('compress: a quality off the steps still shows as is', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(export: ExportOptions(quality: 85)),
      );
      await openCompress(tester);

      expect(find.text('High · 85'), findsOneWidget);
      expect(sliderValue(tester), 90);
      final slider = qualitySliderSemantics();
      expect(slider.value, 'High · 85');
      expect(slider.increasedValue, 'High · 100');
      expect(slider.decreasedValue, 'High · 80');

      // Applying without moving the slider keeps 85.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(controller.quality, 85);
      expect(controller.canUndo, isFalse);
      semantics.dispose();
    });

    testWidgets('compress: screen readers hear the quality and the button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpReadyEditor(tester);
      await openCompress(tester);

      expect(find.semantics.byLabel('Quality'), findsOne);
      expect(
        tester.getSemantics(find.text('Image quality').last),
        matchesSemantics(label: 'Image quality', isHeader: true),
      );
      final slider = qualitySliderSemantics();
      expect(slider.value, 'High · 90');
      expect(slider.increasedValue, 'High · 100');
      expect(slider.decreasedValue, 'High · 80');
      expect(
        tester.getSemantics(find.text('Apply')),
        matchesSemantics(
          label: 'Apply',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Apply'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      semantics.dispose();
    });

    testWidgets('compress: the sheet fits a small phone screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpReadyEditor(tester);

      await openCompress(tester);
      // The spinner never settles, so pump past the sheet's first frames.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Apply')).bottom, lessThan(480));
      await settleEstimate(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compress: apply uses the send button colors', (tester) async {
      await pumpReadyEditor(
        tester,
        theme: const ChatImageEditorThemeData(
          sendButtonColor: Color(0xFF00897B),
          sendButtonForegroundColor: Color(0xFFFFF59D),
        ),
      );
      await openCompress(tester);

      final material = find
          .ancestor(of: find.text('Apply'), matching: find.byType(Material))
          .first;
      expect(tester.widget<Material>(material).color, const Color(0xFF00897B));
      final label = tester.widget<Text>(find.text('Apply'));
      expect(label.style?.color, const Color(0xFFFFF59D));
      // Full width: as wide as the slider above it.
      expect(
        tester.getSize(material).width,
        tester.getSize(find.byType(Slider)).width,
      );
      await settleEstimate(tester);
    });
  });
}
