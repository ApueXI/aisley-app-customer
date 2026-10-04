import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/ui/foreground_poll.dart';

void main() {
  testWidgets('hidden desktop inbox pauses timer, focus and resume probes', (
    tester,
  ) async {
    var visible = false;
    var requests = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForegroundPoll(
            visible: () => visible,
            paused: () => false,
            refresh: () async {
              requests++;
            },
            child: TextField(focusNode: focus),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    focus.requestFocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests, 0);
    visible = true;
    await tester.pump(const Duration(seconds: 15));
    expect(requests, 1);
    visible = false;
    await tester.pump(const Duration(seconds: 30));
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
