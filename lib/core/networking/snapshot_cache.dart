/// Bounded, short lived in-memory snapshots for public catalog reads.
class SnapshotCache<T> {
  SnapshotCache({
    required this.clock,
    this.freshFor = const Duration(seconds: 60),
    this.capacity = 64,
  });
  final DateTime Function() clock;
  final Duration freshFor;
  final int capacity;
  final _values = <String, _Entry<T>>{};

  T? get(String key) {
    final entry = _values.remove(key);
    if (entry == null || clock().difference(entry.storedAt) >= freshFor) {
      return null;
    }
    _values[key] = entry;
    return entry.value;
  }

  void put(String key, T value) {
    _values.remove(key);
    _values[key] = _Entry(value, clock());
    while (_values.length > capacity) {
      _values.remove(_values.keys.first);
    }
  }

  void clear() => _values.clear();
}

class _Entry<T> {
  const _Entry(this.value, this.storedAt);
  final T value;
  final DateTime storedAt;
}
