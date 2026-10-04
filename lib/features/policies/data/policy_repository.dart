import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'policy_models.dart';

abstract interface class PolicyRepository {
  Future<PublicPolicy> current(PolicyType type, {bool refresh = false});
  Future<PolicyHistory> history(PolicyType type);
  Future<PublicPolicy> version(PolicyType type, int version);
  Future<ConsentStatus> status(SessionLease lease);
  Future<PolicyAcceptance> accept(
    SessionLease lease,
    PolicyType type,
    int version,
  );
}

class ApiPolicyRepository implements PolicyRepository {
  ApiPolicyRepository(this.client, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ApiClient client;
  final DateTime Function() clock;
  final _publicCache = <String, (DateTime, Object)>{};
  static const _path = 'platform/policies/';

  Future<T> _read<T>(
    String path,
    T Function(Object?) parse,
    Duration ttl, {
    bool refresh = false,
  }) async {
    final cached = _publicCache[path];
    if (!refresh && cached != null && clock().isBefore(cached.$1)) {
      return cached.$2 as T;
    }
    final result = parse(Wire(await client.request('GET', path)).field('data'));
    _publicCache.removeWhere((_, entry) => !clock().isBefore(entry.$1));
    if (_publicCache.length >= 32) _publicCache.remove(_publicCache.keys.first);
    _publicCache[path] = (clock().add(ttl), result as Object);
    return result;
  }

  PublicPolicy _policy(Object? value, PolicyType type, int? number) {
    final policy = PublicPolicy.parse(value);
    if (policy.type != type.wire ||
        number != null && policy.version.version != number ||
        number == null && policy.version.status != 'published' ||
        !const ['published', 'superseded'].contains(policy.version.status)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return policy;
  }

  @override
  Future<PublicPolicy> current(PolicyType type, {bool refresh = false}) =>
      _read(
        '$_path${type.wire}',
        (v) => _policy(v, type, null),
        const Duration(seconds: 300),
        refresh: refresh,
      );
  @override
  Future<PolicyHistory> history(PolicyType type) => _read(
    '$_path${type.wire}/history',
    (v) {
      final result = PolicyHistory.parse(v);
      if (result.type != type.wire) throw const ApiFailure(FailureKind.decode);
      return result;
    },
    const Duration(seconds: 60),
  );
  @override
  Future<PublicPolicy> version(PolicyType type, int version) {
    if (version < 1) throw const ApiFailure(FailureKind.decode);
    return _read(
      '$_path${type.wire}/history/$version',
      (v) => _policy(v, type, version),
      const Duration(seconds: 300),
    );
  }

  @override
  Future<ConsentStatus> status(SessionLease lease) async => ConsentStatus.parse(
    Wire(await client.request('GET', 'policy-consent/status', lease: lease))
        .field('data'),
  );
  @override
  Future<PolicyAcceptance> accept(
    SessionLease lease,
    PolicyType type,
    int version,
  ) async {
    if (version < 1) throw const ApiFailure(FailureKind.decode);
    final result = PolicyAcceptance.parse(
      Wire(
        await client.request(
          'POST',
          'policy-consent/${type.wire}/versions/$version/accept',
          body: {'confirmation': true},
          lease: lease,
        ),
      ).field('data'),
    );
    if (result.type != type.wire || result.version.version != version) {
      throw const ApiFailure(FailureKind.decode);
    }
    return result;
  }
}
