import '../core/networking/api_client.dart';
import '../core/security/session_controller.dart';
import '../features/shop_messages/data/shop_repository.dart';
import '../features/shop_messages/presentation/shop_inbox_controller.dart';
import '../features/shop_messages/presentation/shop_thread_controller.dart';
import '../features/logistics_messages/data/logistics_repository.dart';
import '../features/logistics_messages/presentation/logistics_inbox_controller.dart';
import '../features/logistics_messages/presentation/logistics_thread_controller.dart';
import '../features/courier_messages/data/courier_repository.dart';
import '../features/courier_messages/presentation/courier_inbox_controller.dart';
import '../features/courier_messages/presentation/courier_thread_controller.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/questions/data/question_repository.dart';
import '../features/questions/presentation/question_controllers.dart';
import '../features/reviews/data/review_repository.dart';
import '../features/reviews/presentation/review_composer_controller.dart';
import '../features/support/data/support_repository.dart';
import '../features/support/presentation/ticket_controller.dart';
import '../features/support/presentation/ticket_inbox_controller.dart';

/// Session-owned controllers retain unresolved writes while screens come and go.
/// The three channel maps/repositories/read markers never share conversation state.
class CommunicationState {
  CommunicationState(this.session, ApiClient api, {this.uuid}) {
    shops = ShopChatRepository(api);
    logistics = LogisticsChatRepository(api);
    courier = CourierChatRepository(api);
    notifications = NotificationRepository(api);
    questions = QuestionRepository(api);
    reviews = ReviewRepository(api);
    support = SupportRepository(api);
    shopInbox = ShopInboxController(session, shops);
    logisticsInbox = LogisticsInboxController(session, logistics);
    courierInbox = CourierInboxController(session, courier);
    ticketInbox = TicketInboxController(session, support);
    session.registerPrivateCleanup(_clearMaps);
  }
  final SessionController session;
  final String Function()? uuid;
  late final ShopChatRepository shops;
  late final LogisticsChatRepository logistics;
  late final CourierChatRepository courier;
  late final NotificationRepository notifications;
  late final QuestionRepository questions;
  late final ReviewRepository reviews;
  late final SupportRepository support;
  late final ShopInboxController shopInbox;
  late final LogisticsInboxController logisticsInbox;
  late final CourierInboxController courierInbox;
  late final TicketInboxController ticketInbox;
  final _shop = <String, ShopThreadController>{};
  final _logistics = <String, LogisticsThreadController>{};
  final _courier = <String, CourierThreadController>{};
  final _ask = <String, AskQuestionController>{};
  final _review = <String, ReviewComposerController>{};
  final _ticket = <String, TicketController>{};
  ShopThreadController shopThread({
    String? id,
    String? shop,
    String? contextType,
    String? contextId,
  }) {
    for (final controller in _shop.values) {
      if (id != null && controller.id == id ||
          shop != null &&
              controller.entry['shop_id'] == shop &&
              controller.pending != null) {
        return controller;
      }
    }
    final key = id ?? '$shop/$contextType/$contextId';
    return _shop.putIfAbsent(
      key,
      () => ShopThreadController(
        session,
        shops,
        id: id,
        uuid: uuid,
        entry: {
          'shop_id': ?shop,
          if (contextId != null) ...{
            'context_type': contextType,
            'context_id': contextId,
          },
        },
      ),
    );
  }

  LogisticsThreadController logisticsThread({String? id, String? order}) {
    for (final controller in _logistics.values) {
      if (id != null && controller.id == id) return controller;
    }
    return _logistics.putIfAbsent(
      id ?? 'order/$order',
      () => LogisticsThreadController(
        session,
        logistics,
        id: id,
        uuid: uuid,
        entry: {
          if (order != null) ...{'context_type': 'order', 'context_id': order},
        },
      ),
    );
  }

  CourierThreadController courierThread({String? id, String? order}) {
    for (final controller in _courier.values) {
      if (id != null && controller.id == id) return controller;
    }
    return _courier.putIfAbsent(
      id ?? 'order/$order',
      () => CourierThreadController(
        session,
        courier,
        id: id,
        uuid: uuid,
        entry: {
          if (order != null) ...{'context_type': 'order', 'context_id': order},
        },
      ),
    );
  }

  AskQuestionController ask(String product) => _ask.putIfAbsent(
    product,
    () => AskQuestionController(session, questions, product, uuid: uuid),
  );
  ReviewComposerController review(
    String item,
    String product, {
    String? reviewId,
  }) => _review.putIfAbsent(
    item,
    () => ReviewComposerController(
      session,
      reviews,
      item,
      product,
      reviewId: reviewId,
    ),
  );
  TicketController ticket([String? id]) {
    for (final controller in _ticket.values) {
      if (id != null && controller.id == id) return controller;
    }
    // After confirmed creation a fresh New ticket form starts a new intent.
    if (id == null && _ticket['new']?.id != null) {
      _ticket.remove('new')?.dispose();
    }
    return _ticket.putIfAbsent(
      id ?? 'new',
      () => TicketController(session, support, id: id, uuid: uuid),
    );
  }

  void _clearMaps() {
    if (session.customer != null &&
        session.verifiedLease?.isCurrent() == true) {
      return;
    }
    for (final c in [
      ..._shop.values,
      ..._logistics.values,
      ..._courier.values,
      ..._ask.values,
      ..._review.values,
      ..._ticket.values,
    ]) {
      c.dispose();
    }
    _shop.clear();
    _logistics.clear();
    _courier.clear();
    _ask.clear();
    _review.clear();
    _ticket.clear();
  }

  void dispose() {
    session.unregisterPrivateCleanup(_clearMaps);
    for (final c in [
      shopInbox,
      logisticsInbox,
      courierInbox,
      ticketInbox,
      ..._shop.values,
      ..._logistics.values,
      ..._courier.values,
      ..._ask.values,
      ..._review.values,
      ..._ticket.values,
    ]) {
      c.dispose();
    }
  }
}
