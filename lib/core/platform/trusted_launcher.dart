import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class TrustedLauncher {
  TrustedLauncher(this.config);
  final AppConfig config;
  Future<bool> open(String value) async {
    final uri = config.trustedLink(value);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
