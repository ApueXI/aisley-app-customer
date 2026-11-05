import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/consent_screen.dart';

import '../support/fakes.dart';
import 'consent_test.dart' show both;

void main() {
  setUpAll(() async {
    final path = Platform.environment['CONSENT_REVIEW_FONT'];
    if (path != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('combined consent $width/$scale/${brightness.name}', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final policies = FakePolicies()
            ..consent = ConsentStatus.parse(both());
          final session = SessionController(
            FakeAuth(),
            policies,
            MemoryTokenStore()..token = 'synthetic-test-token',
          );
          await session.bootstrap();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: buyerTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: ConsentScreen(
                  repository: policies,
                  session: session,
                  launcher: TrustedLauncher(
                    AppConfig(
                      apiBaseUrl: 'https://api.example.invalid',
                      storefrontOrigin: 'https://shop.example.invalid',
                    ),
                  ),
                  returnTo: '/',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CheckboxListTile), findsNWidgets(2));
          expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Accept'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await capture(tester, boundary, '${brightness.name}-reading');
          }
          final tiles = find.byType(CheckboxListTile);
          await tester.ensureVisible(tiles.first);
          await tester.tap(tiles.first);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Accept'),
                )
                .onPressed,
            isNull,
          );
          await tester.ensureVisible(tiles.last);
          await tester.tap(tiles.last);
          await tester.pumpAndSettle();
          final accept = find.widgetWithText(FilledButton, 'Accept');
          await tester.ensureVisible(accept);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await capture(tester, boundary, '${brightness.name}-confirmation');
          }
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(policies.accepts, 1);
          expect(session.active, true);
          await tester.pumpWidget(const SizedBox.shrink());
          session.dispose();
        });
      }
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  await tester.runAsync(() async {
    await Directory('build/consent-review').create(recursive: true);
    await File('build/consent-review/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image!.dispose();
}
