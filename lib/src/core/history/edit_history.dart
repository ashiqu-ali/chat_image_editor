import '../../models/image_edit_value.dart';

/// Undo/redo stack of [ImageEditValue] snapshots.
///
/// Snapshots share their immutable lists, so each entry costs a few
/// pointers. Internal: not exported from the package.
class EditHistory {
  /// Starts a history whose only entry is [initial].
  EditHistory(ImageEditValue initial, {this.maxEntries = 100})
    : assert(maxEntries >= 2),
      _entries = <ImageEditValue>[initial];

  /// Most entries kept; the oldest are dropped first.
  final int maxEntries;

  final List<ImageEditValue> _entries;
  int _index = 0;

  /// The entry the editor currently shows.
  ImageEditValue get current => _entries[_index];

  /// Whether [undo] can step back.
  bool get canUndo => _index > 0;

  /// Whether [redo] can step forward.
  bool get canRedo => _index < _entries.length - 1;

  /// Number of entries, including the initial one.
  int get length => _entries.length;

  /// Records [value] as a new entry after [current], dropping any redo
  /// entries. Returns `false` (and records nothing) if [value] equals
  /// [current].
  bool push(ImageEditValue value) {
    if (value == current) return false;
    _entries.removeRange(_index + 1, _entries.length);
    _entries.add(value);
    _index = _entries.length - 1;
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
      _index--;
    }
    return true;
  }

  /// Replaces [current] in place, without adding an entry or touching the
  /// redo entries.
  void replaceCurrent(ImageEditValue value) {
    _entries[_index] = value;
  }

  /// Steps back and returns the new [current], or `null` if [canUndo] is
  /// `false`.
  ImageEditValue? undo() {
    if (!canUndo) return null;
    _index--;
    return current;
  }

  /// Steps forward and returns the new [current], or `null` if [canRedo] is
  /// `false`.
  ImageEditValue? redo() {
    if (!canRedo) return null;
    _index++;
    return current;
  }

  /// Drops every entry and starts over from [initial].
  void reset(ImageEditValue initial) {
    _entries
      ..clear()
      ..add(initial);
    _index = 0;
  }
}
