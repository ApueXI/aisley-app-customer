import 'dart:async';

import 'package:aisley_mobile_buyer/core/ui/foreground_poll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, ForegroundPoll poll) async {
    await tester.pumpWidget(MaterialApp(home: poll));
    await tester.pump();
  }

  testWidgets('automatic reads never overlap a pending refresh', (
    tester,
  ) async {
    var reads = 0;
    final pending = Completer<void>();
    await show(
      tester,
      ForegroundPoll(
        interval: const Duration(seconds: 5),
        paused: () => false,
        refresh: () {
          reads++;
          return pending.future;
        },
        child: const Scaffold(body: Text('Conversation')),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(reads, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hard pause gates timer, focus and lifecycle resume', (
    tester,
  ) async {
    var reads = 0;
    var paused = true;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await show(
      tester,
      ForegroundPoll(
        paused: () => paused,
        refresh: () async => reads++,
        child: Scaffold(body: TextField(focusNode: focus)),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    focus.requestFocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 0);
    paused = false;
    await tester.pump(const Duration(seconds: 15));
    expect(reads, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recoverable offline reads use bounded probes and recover', (
    tester,
  ) async {
    var reads = 0;
    var offline = true;
    await show(
      tester,
      ForegroundPoll(
        interval: const Duration(seconds: 5),
        retryInterval: const Duration(seconds: 30),
        paused: () => false,
        recoverable: () => offline,
        refresh: () async {
          reads++;
          offline = false;
        },
        child: const Scaffold(body: Text('Offline conversation')),
      ),
    );
    await tester.pump(const Duration(seconds: 25));
    expect(reads, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background and covered routes stop reads; dispose stops timers',
    (tester) async {
      var reads = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ForegroundPoll(
            interval: const Duration(seconds: 5),
            paused: () => false,
            refresh: () async => reads++,
            child: const Scaffold(body: Text('Conversation')),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(reads, 1);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(reads, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 20));
      expect(reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(reads, 2);
    },
  );

  testWidgets('initial background state does not start traffic', (
    tester,
  ) async {
    var reads = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await show(
      tester,
      ForegroundPoll(
        interval: const Duration(seconds: 5),
        paused: () => false,
        refresh: () async => reads++,
        child: const Scaffold(body: Text('Conversation')),
      ),
    );
    await tester.pump(const Duration(seconds: 20));
    expect(reads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
