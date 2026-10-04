import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import '../../../core/networking/cursor_page.dart';
import '../../../core/commerce/commerce_value.dart';
import 'courier_models.dart';

class CourierChatRepository {
  CourierChatRepository(this.api);
  final ApiClient api;
  static const base = 'customer/courier-conversations';
  Future<CursorPage<CourierConversation>> inbox(
    SessionLease lease, [
    String? cursor,
  ]) async {
    final w = Wire(
      await api.request(
        'GET',
        base,
        lease: lease,
        queryParameters: {'cursor': cursor},
      ),
    );
    final meta = Wire(w.object('meta'));
    return CursorPage(
      w.list('data', CourierConversation.parse),
      checkedCursor(meta, 'next_cursor'),
      unread: nonnegative(meta, 'unread_count'),
    );
  }

  Future<CourierConversation> detail(SessionLease lease, String id) async =>
      CourierConversation.parse(
        Wire(await api.request('GET', '$base/${requireUuid(id)}', lease: lease))
            .object('data'),
      );
  Future<CursorPage<CourierMessage>> history(
    SessionLease lease,
    String id, [
    String? cursor,
  ]) async {
    final w = Wire(
      await api.request(
        'GET',
        '$base/${requireUuid(id)}/messages',
        lease: lease,
        queryParameters: {'cursor': cursor},
      ),
    );
    final meta = Wire(w.object('meta'));
    return CursorPage(
      w.list('data', CourierMessage.parse),
      checkedCursor(meta, 'next_cursor'),
    );
  }

  Future<(CourierConversation, CourierMessage)> write(
    SessionLease lease,
    String? id,
    Map<String, dynamic> body,
    String key,
  ) async {
    final w = Wire(
      await api.request(
        'POST',
        id == null ? base : '$base/${requireUuid(id)}/messages',
        lease: lease,
        body: body,
        idempotencyKey: key,
      ),
    );
    return (
      CourierConversation.parse(w.object('conversation')),
      CourierMessage.parse(w.object('message')),
    );
  }

  Future<CourierConversation> read(
    SessionLease lease,
    String id,
    int sequence,
  ) async => CourierConversation.parse(
    Wire(
      await api.request(
        'POST',
        '$base/${requireUuid(id)}/read',
        lease: lease,
        body: {'last_read_sequence': sequence},
      ),
    ).object('data'),
  );
  Future<CourierOrderContext> orderContext(
    SessionLease lease,
    String order,
  ) async => CourierOrderContext.parse(
    Wire(
      await api.request(
        'GET',
        '$base/order-context/${requireUuid(order)}',
        lease: lease,
      ),
    ).object('data'),
  );
}
