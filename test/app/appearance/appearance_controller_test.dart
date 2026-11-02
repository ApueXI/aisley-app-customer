import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_controller.dart';

class MemoryAppearanceStore implements AppearanceStore {
  String? value;
  bool readFails = false, writeFails = false;
  Completer<String?>? pendingRead;
  Completer<void>? pendingWrite;
  final writes = <String>[];
  @override
  Future<String?> read() async {
    if (readFails) throw StateError('unavailable');
    return pendingRead == null ? value : pendingRead!.future;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeFails) throw StateError('unavailable');
    this.value = value;
  }
}

void main() {
  test(
    'missing, invalid and unavailable storage preserve the app default',
    () async {
      for (final value in [null, 'unknown', 'DARK']) {
        final store = MemoryAppearanceStore()..value = value;
        final controller = AppearanceController(
          store: store,
          defaultMode: ThemeMode.light,
        );
        await controller.restore();
        expect(controller.mode, ThemeMode.light);
        store.readFails = true;
        await controller.restore();
        expect(controller.mode, ThemeMode.light);
        controller.dispose();
      }
    },
  );

  test(
    'every explicit choice persists and restores in a new controller',
    () async {
      final store = MemoryAppearanceStore();
      for (final mode in ThemeMode.values) {
        final controller = AppearanceController(
          store: store,
          defaultMode: ThemeMode.light,
        );
        await controller.select(mode);
        expect(store.value, mode.name);
        controller.dispose();
        final restored = AppearanceController(
          store: store,
          defaultMode: ThemeMode.light,
        );
        await restored.restore();
        expect(restored.mode, mode);
        restored.dispose();
      }
    },
  );

  test('failed saves keep immediate appearance and allow retry', () async {
    final store = MemoryAppearanceStore()..writeFails = true;
    final controller = AppearanceController(
      store: store,
      defaultMode: ThemeMode.light,
    );
    final save = controller.select(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);
    await save;
    expect(controller.saveFailed, true);
    store.writeFails = false;
    await controller.retry();
    expect(controller.saveFailed, false);
    expect(store.value, 'dark');
    controller.dispose();
  });

  test(
    'rapid changes serialize writes and persist the latest selection',
    () async {
      final store = MemoryAppearanceStore()..pendingWrite = Completer<void>();
      final controller = AppearanceController(
        store: store,
        defaultMode: ThemeMode.light,
      );
      final first = controller.select(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      final second = controller.select(ThemeMode.light);
      expect(controller.mode, ThemeMode.light);
      expect(store.writes, ['dark']);
      store.pendingWrite!.complete();
      await Future.wait([first, second]);
      expect(store.writes, ['dark', 'light']);
      expect(store.value, 'light');
      expect(controller.saving, false);
      controller.dispose();
    },
  );

  test('an obsolete restore cannot replace a deliberate selection', () async {
    final store = MemoryAppearanceStore()..pendingRead = Completer<String?>();
    final controller = AppearanceController(
      store: store,
      defaultMode: ThemeMode.light,
    );
    final restoring = controller.restore();
    await controller.select(ThemeMode.light);
    store.pendingRead!.complete('dark');
    await restoring;
    expect(controller.mode, ThemeMode.light);
    controller.dispose();
  });

  testWidgets('unavailable reads time out without blocking startup', (
    tester,
  ) async {
    final store = MemoryAppearanceStore()..pendingRead = Completer<String?>();
    final controller = AppearanceController(
      store: store,
      defaultMode: ThemeMode.light,
    );
    final restoring = controller.restore();
    await tester.pump(const Duration(seconds: 4));
    await restoring;
    expect(controller.mode, ThemeMode.light);
    controller.dispose();
  });

  test('late restore and save completions are safe after disposal', () async {
    final store = MemoryAppearanceStore()
      ..pendingRead = Completer<String?>()
      ..pendingWrite = Completer<void>();
    final controller = AppearanceController(
      store: store,
      defaultMode: ThemeMode.light,
    );
    final restoring = controller.restore();
    final saving = controller.select(ThemeMode.dark);
    controller.dispose();
    store.pendingRead!.complete('light');
    store.pendingWrite!.complete();
    await Future.wait([restoring, saving]);
  });
}
