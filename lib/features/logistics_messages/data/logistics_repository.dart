import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import '../../../core/networking/cursor_page.dart';
import '../../../core/commerce/commerce_value.dart';
import 'logistics_models.dart';

class LogisticsChatRepository {
  LogisticsChatRepository(this.api);
  final ApiClient api;
  static const base = 'customer/logistics-conversations';
  Future<CursorPage<LogisticsConversation>> inbox(
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
      w.list('data', LogisticsConversation.parse),
      checkedCursor(meta, 'next_cursor'),
      unread: nonnegative(meta, 'unread_count'),
    );
  }

  Future<LogisticsConversation> detail(SessionLease lease, String id) async =>
      LogisticsConversation.parse(
        Wire(await api.request('GET', '$base/${requireUuid(id)}', lease: lease))
            .object('data'),
      );
  Future<CursorPage<LogisticsMessage>> history(
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
      w.list('data', LogisticsMessage.parse),
      checkedCursor(meta, 'next_cursor'),
    );
  }

  Future<(LogisticsConversation, LogisticsMessage)> write(
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
      LogisticsConversation.parse(w.object('conversation')),
      LogisticsMessage.parse(w.object('message')),
    );
  }

  Future<LogisticsConversation> read(
    SessionLease lease,
    String id,
    int sequence,
  ) async => LogisticsConversation.parse(
    Wire(
      await api.request(
        'POST',
        '$base/${requireUuid(id)}/read',
        lease: lease,
        body: {'last_read_sequence': sequence},
      ),
    ).object('data'),
  );
}
