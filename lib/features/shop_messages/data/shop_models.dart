import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/commerce/commerce_value.dart';

class ShopConversation {
  ShopConversation.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    final shop = Wire(w.object('shop'));
    shopId = shop.uuid('id');
    label = shop.string('name');
    slug = shop.nullableString('slug');
    if (w.field('customer_name') != null) {
      throw const ApiFailure(FailureKind.decode);
    }
    reason = null;
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
  bool get sendAllowed => allowed;
  late final String shopId;
  late final String? slug;
}

class ShopMessageContext {
  ShopMessageContext.parse(Object? json) {
    final w = Wire(json);
    type = w.string('type');
    id = nullableUuid(w, 'id');
    label = w.string('label');
    url = w.nullableString('url');
  }
  late final String type, label;
  late final String? id, url;
}

class ShopMessage {
  ShopMessage.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    sequence = w.positiveInt('sequence');
    body = w.string('body');
    mine = w.boolean('mine');
    role = w.string('sender_role');
    at = w.timestamp('created_at');
    final raw = w.field('context');
    context = raw == null ? null : ShopMessageContext.parse(raw);
  }
  late final String id, body, role;
  late final int sequence;
  late final bool mine;
  late final DateTime? at;
  late final ShopMessageContext? context;
}
