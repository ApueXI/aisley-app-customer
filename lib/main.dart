import 'app/appearance/appearance_controller.dart';
import 'app/appearance/appearance_scope.dart';
import 'app/appearance/appearance_store.dart';

import 'core/chat_media/media_platform.dart';

import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/buyer_app.dart';
import 'app/theme.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cleanAbandonedChatMedia();
  final appearance = AppearanceController(
    store: DeviceAppearanceStore(),
    defaultMode: ThemeMode.light,
  );
  await appearance.restore();
  try {
    final config = await AppConfig.load();
    runApp(
      AppearanceRoot(
        controller: appearance,
        child: BuyerApp(dependencies: AppDependencies.production(config)),
      ),
    );
  } on FormatException {
    runApp(
      AppearanceRoot(
        controller: appearance,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: buyerTheme(),
            darkTheme: buyerTheme(Brightness.dark),
            themeMode:
                AppearanceScope.maybeOf(context)?.mode ?? ThemeMode.light,
            home: const Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'The service configuration is unavailable. Please contact the app provider.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
