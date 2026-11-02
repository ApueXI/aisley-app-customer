import 'package:flutter/material.dart';

abstract interface class AppearanceStore {
  Future<String?> read();
  Future<void> write(String value);
}

String appearanceLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

/// Device appearance is independent of identity and private account state.
class AppearanceController extends ChangeNotifier {
  AppearanceController({required this.store, required ThemeMode defaultMode})
    : _mode = defaultMode;

  final AppearanceStore store;
  ThemeMode _mode;
  ThemeMode get mode => _mode;
  bool saveFailed = false;
  bool saving = false;
  bool _disposed = false;
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  Future<void> restore() async {
    final revision = _revision;
    try {
      final stored = await store.read().timeout(const Duration(seconds: 3));
      if (_disposed || revision != _revision) return;
      _mode = switch (stored) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => _mode,
      };
      notifyListeners();
    } catch (_) {
      // Appearance storage must never block startup or authentication.
    }
  }

  Future<void> select(ThemeMode mode) {
    if (_disposed) return Future<void>.value();
    _mode = mode;
    saveFailed = false;
    saving = true;
    final revision = ++_revision;
    notifyListeners();
    // Serialize writes, including changes made before an earlier save finishes.
    _writes = _writes.then((_) async {
      try {
        await store.write(mode.name);
        if (_disposed || revision != _revision) return;
        saving = false;
        saveFailed = false;
      } catch (_) {
        if (_disposed || revision != _revision) return;
        saving = false;
        saveFailed = true;
      }
      notifyListeners();
    });
    return _writes;
  }

  Future<void> retry() => select(_mode);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
