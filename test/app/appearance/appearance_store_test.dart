import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_controller.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'device appearance persists without modifying other preferences',
    () async {
      SharedPreferences.setMockInitialValues({'unrelated': 'preserved'});
      final controller = AppearanceController(
        store: DeviceAppearanceStore(),
        defaultMode: ThemeMode.light,
      );
      await controller.select(ThemeMode.dark);
      expect(
        (await SharedPreferences.getInstance()).getString('unrelated'),
        'preserved',
      );
      final restored = AppearanceController(
        store: DeviceAppearanceStore(),
        defaultMode: ThemeMode.light,
      );
      await restored.restore();
      expect(restored.mode, ThemeMode.dark);
      controller.dispose();
      restored.dispose();
    },
  );
}
