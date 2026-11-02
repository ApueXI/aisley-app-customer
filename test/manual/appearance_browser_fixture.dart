// Synthetic appearance verification: no live API or real credentials.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_controller.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_scope.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_store.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/core/security/token_store.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_repository.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/account_home_screen.dart';

late SemanticsHandle semantics;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  final appearance = AppearanceController(
    store: DeviceAppearanceStore(),
    defaultMode: ThemeMode.light,
  );
  await appearance.restore();
  final session = SessionController(_Auth(), _Policies(), _Token())
    ..phase = SessionPhase.active
    ..customer = CustomerIdentity.parse({
      'id': '11111111-1111-4111-8111-111111111111',
      'displayName': 'Maya Santos',
      'avatarUrl': null,
      'role': 'customer',
      'status': 'active',
    });
  runApp(
    AppearanceRoot(
      controller: appearance,
      child: Builder(
        builder: (context) => MaterialApp(
          theme: buyerTheme(),
          darkTheme: buyerTheme(Brightness.dark),
          themeMode: AppearanceScope.maybeOf(context)!.mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                Uri.base.queryParameters['text'] == 'large' ? 2 : 1,
              ),
            ),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Account')),
            body: AccountHomeScreen(session: session),
          ),
        ),
      ),
    ),
  );
}

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Policies implements PolicyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Token implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
