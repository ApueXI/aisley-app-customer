import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_controller.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_scope.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_tile.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';

import 'appearance_controller_test.dart' show MemoryAppearanceStore;

void main() {
  testWidgets(
    'choices apply immediately, cancel preserves selection, and failures retry',
    (tester) async {
      final store = MemoryAppearanceStore();
      final controller = AppearanceController(
        store: store,
        defaultMode: ThemeMode.light,
      );
      await tester.pumpWidget(_Harness(controller: controller));
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
            .groupValue,
        ThemeMode.light,
      );
      for (final label in ['System', 'Light', 'Dark']) {
        expect(
          find.widgetWithText(RadioListTile<ThemeMode>, label),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.light);
      expect(store.writes, isEmpty);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      store.writeFails = true;
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppearanceTile))).brightness,
        Brightness.dark,
      );
      expect(find.text('Retry saving'), findsOneWidget);
      store.writeFails = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving'), findsNothing);
      expect(store.value, 'dark');
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.dark);
    },
  );

  testWidgets(
    'System follows device brightness and explicit modes override it',
    (tester) async {
      final controller = AppearanceController(
        store: MemoryAppearanceStore(),
        defaultMode: ThemeMode.system,
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(_Harness(controller: controller));
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(AppearanceTile))).brightness;
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await controller.select(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      await controller.select(ThemeMode.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
    },
  );

  testWidgets('theme changes preserve the pushed route and form draft', (
    tester,
  ) async {
    final controller = AppearanceController(
      store: MemoryAppearanceStore(),
      defaultMode: ThemeMode.light,
    );
    await tester.pumpWidget(_Harness(controller: controller));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Retained draft');
    await controller.select(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('Retained draft'), findsOneWidget);
    expect(find.text('Profile form'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceTile), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'appearance at $size, $brightness and doubled text is accessible',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final controller = AppearanceController(
              store: MemoryAppearanceStore(),
              defaultMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
            );
            await tester.pumpWidget(_Harness(controller: controller, scale: 2));
            expect(
              tester.getSize(find.byType(ListTile)).height,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.text('Appearance'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Dark').last);
            await tester.pumpAndSettle();
            expect(
              tester
                  .getSize(
                    find.widgetWithText(RadioListTile<ThemeMode>, 'Dark'),
                  )
                  .height,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.text('Dark').last);
            await tester.pumpAndSettle();
            expect(controller.mode, ThemeMode.dark);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.controller, this.scale = 1});
  final AppearanceController controller;
  final double scale;
  @override
  Widget build(BuildContext context) => AppearanceRoot(
    controller: controller,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: buyerTheme(),
        darkTheme: buyerTheme(Brightness.dark),
        themeMode: AppearanceScope.maybeOf(context)!.mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                const AppearanceTile(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        appBar: null,
                        body: Column(
                          children: [Text('Profile form'), TextField()],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Edit profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
