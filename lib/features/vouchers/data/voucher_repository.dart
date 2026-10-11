import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/snapshot_cache.dart';
import '../../../core/networking/wire.dart';
import 'customer_voucher.dart';

class VoucherRepository {
  VoucherRepository(this.api, {DateTime Function()? clock})
    : _public = SnapshotCache<Object>(clock: clock ?? DateTime.now);
  final ApiClient api;
  final SnapshotCache<Object> _public;
  final _requests = <String, Object>{};

  Future<VoucherPage> list({
    String? shopSlug,
    String? issuer,
    String? benefit,
    int page = 1,
    int limit = 20,
    bool refresh = false,
  }) async {
    final path = shopSlug == null
        ? 'customer/vouchers'
        : 'customer/shops/${_slug(shopSlug)}/vouchers';
    final query = _query(issuer, benefit, page, limit);
    final key = '$path:$issuer:$benefit:$page:$limit';
    return _cached(
      key,
      refresh,
      () async => VoucherPage.parse(
        await api.request('GET', path, queryParameters: query),
        private: false,
      ),
    );
  }

  Future<CustomerVoucher> detail(String id, {bool refresh = false}) =>
      _cached('detail:${requireUuid(id)}', refresh, () async {
        final result = CustomerVoucher.parse(
          Wire(await api.request('GET', 'customer/vouchers/$id'))
              .object('data'),
          private: false,
        );
        if (result.id != id) throw const ApiFailure(FailureKind.decode);
        return result;
      });

  Future<VoucherPage> mine(
    SessionLease lease, {
    String status = 'available',
    String? issuer,
    String? benefit,
    int page = 1,
    int limit = 20,
  }) async {
    if (!const ['available', 'upcoming', 'history'].contains(status)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return VoucherPage.parse(
      await api.request(
        'GET',
        'customer/my-vouchers',
        lease: lease,
        queryParameters: {
          ..._query(issuer, benefit, page, limit),
          'status': status,
        },
      ),
      private: true,
    );
  }

  Future<List<CustomerVoucher>> statuses(
    SessionLease lease,
    List<String> ids,
  ) async {
    if (ids.isEmpty || ids.length > 50 || ids.toSet().length != ids.length) {
      throw const ApiFailure(FailureKind.decode);
    }
    ids.forEach(requireUuid);
    final rows = Wire(
      await api.request(
        'GET',
        'customer/voucher-statuses',
        lease: lease,
        queryParameters: {
          for (var i = 0; i < ids.length; i++) 'ids[$i]': ids[i],
        },
      ),
    ).list('items', (v) => CustomerVoucher.parse(v, private: true));
    if (rows.map((v) => v.id).toSet().length != rows.length ||
        rows.any((v) => !ids.contains(v.id))) {
      throw const ApiFailure(FailureKind.decode);
    }
    return rows;
  }

  Future<CustomerVoucher> collect(
    SessionLease lease,
    CustomerVoucher voucher,
  ) async {
    if (!voucher.supported ||
        voucher.issuer == 'shop' && voucher.shop == null) {
      throw const ApiFailure(FailureKind.decode);
    }
    final path = voucher.issuer == 'shop'
        ? 'customer/shops/${_slug(voucher.shop!.slug)}/vouchers/${requireUuid(voucher.id)}/claim'
        : 'customer/vouchers/${requireUuid(voucher.id)}/claim';
    final row = CustomerVoucher.parse(
      Wire(await api.request('POST', path, lease: lease)).object('data'),
      private: true,
    );
    if (row.id != voucher.id ||
        row.issuer != voucher.issuer ||
        voucher.issuer == 'shop' && row.shop?.id != voucher.shop?.id ||
        row.distribution == 'claim_required' && row.collected != true) {
      throw const ApiFailure(FailureKind.decode);
    }
    return row;
  }

  Map<String, Object?> _query(
    String? issuer,
    String? benefit,
    int page,
    int limit,
  ) {
    if (page < 1 ||
        page > 10000 ||
        limit < 1 ||
        limit > 50 ||
        issuer != null && !const ['app', 'shop'].contains(issuer) ||
        benefit != null && !const ['discount', 'shipping'].contains(benefit)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return {
      'issuer': ?issuer,
      'benefit': ?benefit,
      'page': page,
      'limit': limit,
    };
  }

  String _slug(String value) {
    if (!validShopSlug(value)) throw const ApiFailure(FailureKind.decode);
    return Uri.encodeComponent(value);
  }

  Future<T> _cached<T extends Object>(
    String key,
    bool refresh,
    Future<T> Function() read,
  ) async {
    final cached = refresh ? null : _public.get(key);
    if (cached is T) return cached;
    final stamp = Object();
    _requests[key] = stamp;
    try {
      final value = await read();
      if (identical(_requests[key], stamp)) _public.put(key, value);
      return value;
    } finally {
      if (identical(_requests[key], stamp)) _requests.remove(key);
    }
  }

  void dispose() {
    _public.clear();
    _requests.clear();
  }
}
