import '../../../core/networking/wire.dart';
import '../../../core/chat_media/attachment.dart';
import '../../../core/chat_media/message_attachments.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/commerce/commerce_value.dart';

enum ShopAvailability {
  online,
  offline,
  vacation,
  unknown;

  String get label => switch (this) {
    online => 'Shop available',
    offline => 'Shop unavailable',
    vacation => 'Shop on vacation',
    unknown => 'Shop availability unavailable',
  };
}

class ChatShop {
  ChatShop.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    name = w.string('name');
    slug = w.nullableString('slug');
    availability = switch (w.string('availability')) {
      'online' => ShopAvailability.online,
      'offline' => ShopAvailability.offline,
      'vacation' => ShopAvailability.vacation,
      _ => ShopAvailability.unknown,
    };
  }
  late final String id, name;
  late final String? slug;
  late final ShopAvailability availability;
}

class ShopChatContext {
  ShopChatContext.parse(Object? json) {
    final w = Wire(json);
    shop = ChatShop.parse(w.object('shop'));
    conversationId = nullableUuid(w, 'conversation_id');
    sendAllowed = w.boolean('send_allowed');
  }
  late final ChatShop shop;
  late final String? conversationId;
  late final bool sendAllowed;
}

class ShopConversation {
  ShopConversation.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    shop = ChatShop.parse(w.object('shop'));
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
  late final String id;
  late final String? preview, reason;
  late final DateTime? at;
  late final int lastSequence, lastRead, unread;
  late final bool allowed;
  bool get sendAllowed => allowed;
  late final ChatShop shop;
  String get shopId => shop.id;
  String get label => shop.name;
  String? get slug => shop.slug;
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
    attachments = messageAttachments(w.field('attachments'));

    mine = w.boolean('mine');
    role = w.string('sender_role');
    at = w.timestamp('created_at');
    final raw = w.field('context');
    context = raw == null ? null : ShopMessageContext.parse(raw);
  }
  late final String id, body, role;
  late final List<ChatAttachment> attachments;
  late final int sequence;
  late final bool mine;
  late final DateTime? at;
  late final ShopMessageContext? context;
}
