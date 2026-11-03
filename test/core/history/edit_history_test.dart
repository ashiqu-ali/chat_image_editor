import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/history/edit_history.dart';
import 'package:flutter_test/flutter_test.dart';

ImageEditValue turns(int quarterTurns) =>
    ImageEditValue(quarterTurns: quarterTurns % 4, quality: quarterTurns + 1);

void main() {
  test('starts with one entry and nothing to undo or redo', () {
    final history = EditHistory(ImageEditValue.empty);
    expect(history.current, ImageEditValue.empty);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.length, 1);
  });

  test('push, undo and redo step between snapshots', () {
    final history = EditHistory(ImageEditValue.empty);
    expect(history.push(turns(1)), isTrue);
    expect(history.push(turns(2)), isTrue);
    expect(history.current, turns(2));

    expect(history.undo(), turns(1));
    expect(history.undo(), ImageEditValue.empty);
    expect(history.undo(), isNull);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isTrue);

    expect(history.redo(), turns(1));
    expect(history.redo(), turns(2));
    expect(history.redo(), isNull);
  });

  test('pushing the current value records nothing', () {
    final history = EditHistory(turns(1));
    expect(history.push(turns(1)), isFalse);
    expect(history.length, 1);
  });

  test('a new entry drops the redo entries', () {
    final history = EditHistory(ImageEditValue.empty)
      ..push(turns(1))
      ..push(turns(2))
      ..undo();
    history.push(turns(3));
    expect(history.canRedo, isFalse);
    expect(history.length, 3);
    expect(history.undo(), turns(1));
  });

  test('keeps at most maxEntries, dropping the oldest', () {
    final history = EditHistory(ImageEditValue.empty, maxEntries: 3);
    for (var i = 1; i <= 5; i++) {
      history.push(turns(i));
    }
    expect(history.length, 3);
    expect(history.current, turns(5));
    history
      ..undo()
      ..undo();
    expect(history.current, turns(3));
    expect(history.canUndo, isFalse);
  });

  test('replaceCurrent swaps the entry without touching redo', () {
    final history = EditHistory(ImageEditValue.empty)
      ..push(turns(1))
      ..push(turns(2))
      ..undo();
    history.replaceCurrent(turns(7));
    expect(history.current, turns(7));
    expect(history.length, 3);
    expect(history.redo(), turns(2));
    expect(history.undo(), turns(7));
  });

  test('reset starts over', () {
    final history = EditHistory(ImageEditValue.empty)..push(turns(1));
    history.reset(turns(3));
    expect(history.current, turns(3));
    expect(history.length, 1);
    expect(history.canUndo, isFalse);
  });
}
