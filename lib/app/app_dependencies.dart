import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/networking/api_client.dart';
import '../core/platform/http_adapter.dart';
import '../core/platform/trusted_launcher.dart';
import '../core/security/session_controller.dart';
import '../core/security/token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/policies/data/policy_repository.dart';

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.auth,
    required this.policies,
    required this.session,
    required this.launcher,
    DateTime Function()? clock,
    this.client,
  }) : clock = clock ?? DateTime.now;
  factory AppDependencies.production(AppConfig config) {
    final client = ApiClient(config);
    configureHttpAdapter(client.publicClient);
    configureHttpAdapter(client.privateClient);
    final auth = ApiAuthRepository(
      client,
      deviceName: kIsWeb ? 'buyer-local-web' : 'buyer-android',
    );
    final policies = ApiPolicyRepository(client);
    return AppDependencies(
      config: config,
      client: client,
      auth: auth,
      policies: policies,
      session: SessionController(
        auth,
        policies,
        SecureTokenStore(apiOrigin: config.apiBase.origin),
      ),
      launcher: TrustedLauncher(config),
    );
  }
  final AppConfig config;
  final AuthRepository auth;
  final PolicyRepository policies;
  final SessionController session;
  final TrustedLauncher launcher;
  final DateTime Function() clock;
  final ApiClient? client;
  void dispose() {
    session.dispose();
    client?.close();
  }
}
