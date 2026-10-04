import '../../../core/networking/api_client.dart';
import '../../../core/networking/cursor_page.dart';
import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';
import 'support_models.dart';

class SupportRepository {
  SupportRepository(this.api);
  final ApiClient api;
  static const base = 'customer/support-tickets';
  Future<CursorPage<SupportTicket>> list(
    SessionLease lease, {
    String? cursor,
    String? status,
    String? category,
  }) async {
    final w = Wire(
      await api.request(
        'GET',
        base,
        lease: lease,
        queryParameters: {
          'cursor': cursor,
          'status': status,
          'category': category,
          'limit': 20,
        },
      ),
    );
    return CursorPage(
      w.list('items', SupportTicket.parse),
      checkedCursor(w, 'next_cursor'),
    );
  }

  Future<(SupportTicket, CursorPage<TicketEvent>)> detail(
    SessionLease lease,
    String id, [
    String? cursor,
  ]) async {
    final w = Wire(
      await api.request(
        'GET',
        '$base/${requireUuid(id)}',
        lease: lease,
        queryParameters: {'cursor': cursor, 'limit': 30},
      ),
    );
    return (
      SupportTicket.parse(w.object('data')),
      CursorPage(
        w.list('events', TicketEvent.parse),
        checkedCursor(w, 'next_cursor'),
      ),
    );
  }

  Future<(SupportTicket, TicketEvent)> write(
    SessionLease lease,
    String? id,
    Map<String, dynamic> body,
    String key,
  ) async {
    final w = Wire(
      await api.request(
        'POST',
        id == null ? base : '$base/${requireUuid(id)}/replies',
        lease: lease,
        body: body,
        idempotencyKey: key,
      ),
    );
    return (
      SupportTicket.parse(w.object('data')),
      TicketEvent.parse(w.object('event')),
    );
  }

  Future<SupportTicket> read(
    SessionLease lease,
    String id,
    int sequence,
  ) async => SupportTicket.parse(
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
