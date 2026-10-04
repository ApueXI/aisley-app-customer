import 'package:shared_preferences/shared_preferences.dart';

const legacyRecentKey = 'buyer.public_recent_ids_v1';

/// Retire only the old public hints; preference failure cannot block sign-in.
Future<void> removeLegacyRecentHints({
  Future<SharedPreferences> Function()? preferences,
}) async {
  try {
    final store = await (preferences ?? SharedPreferences.getInstance)();
    await store.remove(legacyRecentKey);
  } catch (_) {
    // Best effort; never read or merge the retired hints.
  }
}
