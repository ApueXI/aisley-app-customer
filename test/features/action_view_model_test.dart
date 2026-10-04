import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/action_view_model.dart';

void main() {
  test(
    'readable Retry-After blocks duplicate actions until cooldown ends',
    () async {
      var now = DateTime.utc(2026, 10, 4);
      final model = ActionViewModel(clock: () => now);
      addTearDown(model.dispose);
      var calls = 0;
      Future<void> action() async {
        calls++;
        throw ApiFailure(
          FailureKind.http,
          status: 429,
          retryAt: now.add(const Duration(seconds: 60)),
        );
      }

      await model.submit(action);
      expect(model.enabled, false);
      await model.submit(action);
      expect(calls, 1);
      now = now.add(const Duration(seconds: 61));
      expect(model.enabled, true);
    },
  );
  test('editing a rejected field removes stale server validation', () async {
    final model = ActionViewModel();
    addTearDown(model.dispose);
    await model.submit(
      () async => throw const ApiFailure(
        FailureKind.http,
        status: 422,
        fields: {
          'email': ['Check this field.'],
        },
      ),
    );
    expect(model.fieldError('email'), isNotNull);
    model.clearField('email');
    expect(model.fieldError('email'), null);
  });
  test('reset rejects late action errors and successes', () async {
    final model = ActionViewModel();
    addTearDown(model.dispose);
    final pending = Completer<void>();
    final action = model.submit(() => pending.future);
    model.reset();
    pending.completeError(const ApiFailure(FailureKind.http, status: 401));
    expect(await action, false);
    expect(model.failure, null);
    expect(model.busy, false);
  });
}
