import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/core/ui/form_page.dart';

void main() {
  testWidgets('router Back confirms dirty forms before leaving', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/form',
          builder: (_, _) => const FormPage(
            title: 'Profile',
            dirty: true,
            children: [TextField(autofocus: true)],
          ),
        ),
        GoRoute(
          path: '/next',
          builder: (_, _) => const Scaffold(body: Text('Next destination')),
        ),
      ],
      onEnter: (_, current, next, _) async {
        if (current.uri == next.uri ||
            !FormPageExitRegistry.hasGuard(current)) {
          return const Allow();
        }
        return await FormPageExitRegistry.allowExit(current)
            ? const Allow()
            : const Block.stop();
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/next');
    await tester.pumpAndSettle();
    expect(find.text('Leave this screen?'), findsOneWidget);
    expect(
      find.text('Discard the information entered in this form?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/form');
    expect(find.text('Profile'), findsOneWidget);

    router.go('/next');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/next');
    expect(find.text('Next destination'), findsOneWidget);
  });
}
