import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';

class LogisticsConversation {
  LogisticsConversation.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    kind = w.string('kind');
    orderId = nullableUuid(w, 'order_id');
    orderReference = w.nullableString('order_reference');
    role = w.string('counterparty_role');
    label = w.string('counterparty_label');
    reason = w.nullableString('read_only_reason');
    preview = w.nullableString('last_message_preview');
    at = w.timestamp('last_message_at');
    lastSequence = nonnegative(w, 'last_sequence');
    lastRead = nonnegative(w, 'last_read_sequence');
    unread = nonnegative(w, 'unread_count');
    allowed = w.boolean('send_allowed');
  }
  late final String id, label;
  late final String? preview, reason;
  late final DateTime? at;
  late final int lastSequence, lastRead, unread;
  late final bool allowed;
  bool get sendAllowed =>
      allowed && kind == 'customer_logistics' && role == 'logistics';
  late final String kind, role;
  late final String? orderId, orderReference;
}

class LogisticsMessage {
  LogisticsMessage.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    sequence = w.positiveInt('sequence');
    body = w.string('body');
    mine = w.boolean('mine');
    role = w.string('sender_role');
    at = w.timestamp('created_at');
    conversationId = w.uuid('conversation_id');
  }
  late final String id, body, role;
  late final int sequence;
  late final bool mine;
  late final DateTime? at;
  late final String conversationId;
}
