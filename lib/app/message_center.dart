import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/security/session_controller.dart';
import '../features/courier_messages/presentation/courier_inbox_controller.dart';
import '../features/logistics_messages/presentation/logistics_inbox_controller.dart';
import '../features/messaging/data/conversation_preview.dart';
import '../features/messaging/presentation/conversation_inbox_controller.dart';
import '../features/shop_messages/presentation/shop_inbox_controller.dart';

/// Combines display state without sharing channel identities, cursors or reads.
class MessageCenter extends ChangeNotifier {
  MessageCenter(this.session, this.shops, this.logistics, this.courier) {
    session.addListener(_changed);
    for (final controller in channels.values) {
      controller.addListener(_changed);
    }
  }
  final SessionController session;
  final ShopInboxController shops;
  final LogisticsInboxController logistics;
  final CourierInboxController courier;
  bool _notificationPending = false, _disposed = false;

  Map<MessageChannel, ConversationInboxController<Object>> get channels => {
    MessageChannel.shop: shops,
    MessageChannel.logistics: logistics,
    MessageChannel.courier: courier,
  };
  bool get busy => channels.values.any((c) => c.busy);
  bool get needsRefresh =>
      session.active &&
      channels.values.any(
        (c) => c.needsRefresh && !c.busy && !c.offline && !c.coolingDown,
      );
  int? get unread =>
      !session.active || channels.values.any((c) => !c.loaded || !c.unreadFresh)
      ? null
      : channels.values.fold<int>(0, (total, c) => total + c.unread);
  bool get hasSnapshot => channels.values.any((c) => c.loaded);

  List<ConversationPreview> conversations([MessageChannel? channel]) {
    if (!session.active) return const [];
    final rows = [
      if (channel == null || channel == MessageChannel.shop)
        for (final e in shops.items)
          ConversationPreview(
            channel: MessageChannel.shop,
            id: e.id,
            label: e.label,
            preview: e.preview,
            at: e.at,
            unread: e.unread,
            readOnly: !e.sendAllowed,
          ),
      if (channel == null || channel == MessageChannel.logistics)
        for (final e in logistics.items)
          ConversationPreview(
            channel: MessageChannel.logistics,
            id: e.id,
            label: e.label,
            preview: e.preview,
            at: e.at,
            unread: e.unread,
            readOnly: !e.sendAllowed,
            reference: e.orderReference,
          ),
      if (channel == null || channel == MessageChannel.courier)
        for (final e in courier.items)
          ConversationPreview(
            channel: MessageChannel.courier,
            id: e.id,
            label: e.label,
            preview: e.preview,
            at: e.at,
            unread: e.unread,
            readOnly: !e.sendAllowed,
            reference: e.orderReference,
          ),
    ]..sort(ConversationPreview.compare);
    return List.unmodifiable(rows);
  }

  Future<void> refresh({
    MessageChannel? channel,
    bool automatic = false,
    bool onlyNeeded = false,
  }) async {
    if (!session.active) return;
    await Future.wait([
      for (final entry in channels.entries)
        if ((channel == null || channel == entry.key) &&
            (!onlyNeeded || entry.value.needsRefresh))
          entry.value.load(retain: true, automatic: automatic),
    ]);
  }

  Future<void> loadMore([MessageChannel? channel]) async {
    if (!session.active) return;
    await Future.wait([
      for (final entry in channels.entries)
        if (channel == null || channel == entry.key)
          entry.value.load(more: true),
    ]);
  }

  void invalidate(MessageChannel channel, {String? deniedId}) {
    final controller = channels[channel]!;
    if (deniedId == null) {
      controller.invalidate();
    } else {
      controller.discard(deniedId);
    }
  }

  void markStale() {
    for (final controller in channels.values) {
      controller.markUnreadStale();
    }
  }

  void _changed() {
    if (_notificationPending || _disposed) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_changed);
    for (final controller in channels.values) {
      controller.removeListener(_changed);
    }
    super.dispose();
  }
}
