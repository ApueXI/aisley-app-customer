import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import '../../../core/networking/cursor_page.dart';
import '../../../core/commerce/commerce_value.dart';
import 'shop_models.dart';

class ShopChatRepository {
  ShopChatRepository(this.api);
  final ApiClient api;
  static const base = 'customer/conversations';
  Future<CursorPage<ShopConversation>> inbox(
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
    final meta = w;
    return CursorPage(
      w.list('items', ShopConversation.parse),
      checkedCursor(meta, 'next_cursor'),
      unread: nonnegative(meta, 'unread_count'),
    );
  }

  Future<ShopConversation> detail(SessionLease lease, String id) async =>
      ShopConversation.parse(
        Wire(await api.request('GET', '$base/${requireUuid(id)}', lease: lease))
            .object('data'),
      );
  Future<CursorPage<ShopMessage>> history(
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
    final meta = w;
    return CursorPage(
      w.list('items', ShopMessage.parse),
      checkedCursor(meta, 'next_cursor'),
    );
  }

  Future<(ShopConversation, ShopMessage)> write(
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
      ShopConversation.parse(w.object('conversation')),
      ShopMessage.parse(w.object('message')),
    );
  }

  Future<ShopConversation> read(
    SessionLease lease,
    String id,
    int sequence,
  ) async => ShopConversation.parse(
    Wire(
      await api.request(
        'POST',
        '$base/${requireUuid(id)}/read',
        lease: lease,
        body: {'sequence': sequence},
      ),
    ).object('data'),
  );
  Future<int> unreadCount(SessionLease lease) async => nonnegative(
    Wire(await api.request('GET', '$base/unread-count', lease: lease)),
    'unread_count',
  );
}
