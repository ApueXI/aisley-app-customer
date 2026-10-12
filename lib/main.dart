import 'core/chat_media/media_platform.dart';

import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/buyer_app.dart';
import 'app/theme.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cleanAbandonedChatMedia();
  try {
    runApp(
      BuyerApp(
        dependencies: AppDependencies.production(AppConfig.environment()),
      ),
    );
  } on FormatException {
    runApp(
      MaterialApp(
        theme: buyerTheme(),
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
    );
  }
}
