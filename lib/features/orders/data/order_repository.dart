import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'order_models.dart';
import 'tracking_models.dart';

class OrdersPage {
  OrdersPage.parse(Object? json) {
    page = OrderPage.parse(json, OrderSummary.parse);
    final filters = Wire(Wire(json).object('filters'));
    selected = filters.nullableString('selected');
    tabs = filters.list('tabs', OrderTab.parse);
  }
  late final OrderPage<OrderSummary> page;
  late final String? selected;
  late final List<OrderTab> tabs;
}

class OrderRepository {
  OrderRepository(this.api);
  final ApiClient api;
  Map<String, Object?> _page(int page, int perPage) {
    if (page < 1 || page > 10000 || perPage < 1 || perPage > 50) {
      throw const ApiFailure(FailureKind.decode);
    }
    return {'page': page, 'per_page': perPage};
  }

  Future<OrdersPage> list(
    SessionLease lease, {
    String? group,
    int page = 1,
  }) async {
    if (group != null && !orderGroups.contains(group)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return OrdersPage.parse(
      await api.request(
        'GET',
        'customer/orders',
        lease: lease,
        queryParameters: {..._page(page, 15), 'group': ?group},
      ),
    );
  }

  Future<BuyerOrder> detail(SessionLease lease, String id) async {
    final value = BuyerOrder.parse(
      Wire(
        await api.request(
          'GET',
          'customer/orders/${requireUuid(id)}',
          lease: lease,
        ),
      ).object('data'),
    );
    if (value.id != id) throw const ApiFailure(FailureKind.decode);
    return value;
  }

  Future<OrderPage<TrackingEvent>> tracking(
    SessionLease lease,
    String id,
    int page,
  ) async => OrderPage.parse(
    await api.request(
      'GET',
      'customer/orders/${requireUuid(id)}/tracking',
      lease: lease,
      queryParameters: _page(page, 25),
    ),
    TrackingEvent.parse,
  );
  Future<BuyerOrder> mutate(
    SessionLease lease,
    PendingOrderMutation pending,
  ) async {
    final value = BuyerOrder.parse(
      Wire(
        await api.request(
          pending.kind == OrderMutationKind.correction ? 'PATCH' : 'POST',
          'customer/orders/${requireUuid(pending.orderId)}/${pending.kind.path}',
          lease: lease,
          body: pending.payload,
          idempotencyKey: pending.key,
        ),
      ).object('data'),
    );
    if (value.id != pending.orderId ||
        pending.kind == OrderMutationKind.cancel &&
            value.status != 'cancelled' ||
        pending.kind == OrderMutationKind.correction &&
            value.address.version! <=
                (pending.payload['expected_revision'] as int) ||
        pending.kind == OrderMutationKind.extension &&
            value.preparation?.extensionUsed != true) {
      throw const ApiFailure(FailureKind.decode);
    }
    return value;
  }
}

enum OrderMutationKind {
  cancel('cancel'),
  correction('modification'),
  extension('preparation-extension');

  const OrderMutationKind(this.path);
  final String path;
}

class PendingOrderMutation {
  PendingOrderMutation({
    required this.orderId,
    required this.key,
    required Map<String, dynamic> payload,
    required this.customerId,
    required this.sessionGeneration,
    required this.kind,
  }) : payload = Map.unmodifiable(payload);
  final String orderId, key, customerId;
  final int sessionGeneration;
  final OrderMutationKind kind;
  final Map<String, dynamic> payload;
  @override
  String toString() => 'PendingOrderMutation';
}
