import 'dart:async';

import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/communication_state.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';

import 'fakes.dart';

class CommunicationHarness {
  final auth = FakeAuth(), policies = FakePolicies();
  late SessionController session;
  late ApiClient api;
  late FakeAdapter adapter;
  late CommunicationState state;
  Reply? reply;
  int keys = 0;
  Future<void> initialize({bool active = true}) async {
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = active ? 'synthetic-token' : null,
    );
    await session.bootstrap();
    adapter = FakeAdapter((o) => reply != null ? reply!(o) : defaultReply(o));
    api = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
      privateClient: Dio()..httpClientAdapter = adapter,
      readBackoff: Duration.zero,
      deadline: const Duration(milliseconds: 200),
    );
    state = CommunicationState(
      session,
      api,
      uuid: () =>
          '${(++keys).toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
    );
  }

  FutureOr<ResponseBody> defaultReply(RequestOptions o) {
    final p = o.uri.path;
    final channel = p.contains('logistics-conversations')
        ? 'logistics-messaging'
        : p.contains('courier-conversations')
        ? 'courier-messaging'
        : 'chat-messaging';
    final offset = channel == 'chat-messaging'
        ? 57
        : channel == 'logistics-messaging'
        ? 64
        : 70;
    if (p.contains('conversations')) {
      final relative = p.split('conversations').last;
      final op = relative.contains('order-context')
          ? 76
          : relative.endsWith('/read')
          ? offset + 5
          : relative.endsWith('/messages')
          ? offset + (o.method == 'POST' ? 4 : 3)
          : relative.isEmpty
          ? offset + (o.method == 'POST' ? 1 : 0)
          : offset + 2;
      return jsonReply(
        fixture(channel, 'op-${op.toString().padLeft(3, '0')}'),
        status: o.method == 'POST' && !relative.endsWith('/read') ? 201 : 200,
      );
    }
    if (p.contains('support-tickets')) {
      final relative = p.split('support-tickets').last;
      final op = relative.endsWith('/read')
          ? 81
          : relative.endsWith('/replies')
          ? 80
          : relative.isEmpty
          ? (o.method == 'POST' ? 78 : 77)
          : 79;
      return jsonReply(
        fixture('support-tickets', 'op-0$op'),
        status: op == 78 || op == 80 ? 201 : 200,
      );
    }
    if (p.endsWith('/questions')) {
      return jsonReply(
        fixture('product-qa', o.method == 'POST' ? 'op-050' : 'op-049'),
        status: o.method == 'POST' ? 201 : 200,
      );
    }
    if (p.endsWith('/review')) {
      return jsonReply(
        fixture('product-review-ratings', 'op-052'),
        status: 201,
      );
    }
    if (p.endsWith('/reviews')) {
      return jsonReply(fixture('product-review-ratings', 'op-051'));
    }
    if (p.endsWith('/images')) {
      return jsonReply(
        fixture('product-review-ratings', 'op-053'),
        status: 201,
      );
    }
    if (p.contains('/notifications')) {
      return jsonReply(
        fixture(
          'notifications',
          p.endsWith('/read')
              ? 'op-056'
              : p.endsWith('/notifications')
              ? 'op-054'
              : 'op-055',
        ),
      );
    }
    return jsonReply({}, status: 404);
  }

  AppDependencies dependencies({PhotoPickerAdapter? picker}) => AppDependencies(
    config: testConfig,
    auth: auth,
    policies: policies,
    session: session,
    launcher: TrustedLauncher(testConfig),
    client: api,
    communication: state,
    photoPicker: picker ?? PhotoPickerAdapter(),
    discovery: DiscoveryRepository(api: api, session: session),
  );
  void dispose() {
    state.dispose();
    session.dispose();
    api.close();
  }
}
