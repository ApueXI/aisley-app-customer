import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_controller.dart';

class DeviceAppearanceStore implements AppearanceStore {
  static const key = 'buyer.appearance_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      value,
    );
    if (!saved) throw StateError('Appearance could not be saved');
  }
}
