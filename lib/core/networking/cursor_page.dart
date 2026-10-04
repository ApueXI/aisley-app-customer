import 'api_failure.dart';
import 'wire.dart';

String? checkedCursor(Wire wire, String key) {
  final value = wire.nullableString(key);
  if (value != null && (value.isEmpty || value.length > 2048)) {
    throw const ApiFailure(FailureKind.decode);
  }
  return value;
}

class CursorPage<T> {
  const CursorPage(this.items, this.next, {this.unread = 0});
  final List<T> items;
  final String? next;
  final int unread;
}

/// Retains both the refresh bridge and the old history frontier. Cursors are
/// opaque, never fabricated from IDs. Repeated/no-progress pages stop traversal.
class CursorTrail {
  final _pending = <String>[];
  final _visited = <String>{};
  String? get next => _pending.isEmpty ? null : _pending.first;
  void clear() {
    _pending.clear();
    _visited.clear();
  }

  void seed(String? cursor, {bool gap = false}) {
    if (cursor == null ||
        _pending.contains(cursor) ||
        _visited.contains(cursor)) {
      return;
    }
    if (_pending.isEmpty || gap) _pending.insert(0, cursor);
  }

  void advance(String requested, String? cursor, {required bool progressed}) {
    _pending.remove(requested);
    _visited.add(requested);
    if (progressed &&
        cursor != null &&
        !_visited.contains(cursor) &&
        !_pending.contains(cursor)) {
      _pending.insert(0, cursor);
    }
  }
}
