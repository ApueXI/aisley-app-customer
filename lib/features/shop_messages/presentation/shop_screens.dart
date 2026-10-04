import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/foreground_poll.dart';
import '../../messaging/presentation/message_views.dart';
import 'shop_thread_controller.dart';

class ShopInboxScreen extends StatefulWidget {
  const ShopInboxScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<ShopInboxScreen> createState() => _ShopInboxScreenState();
}

class _ShopInboxScreenState extends State<ShopInboxScreen> {
  late final controller = widget.dependencies.communication!.shopInbox;
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  Widget build(BuildContext context) => ForegroundPoll(
    refresh: controller.load,
    paused: () => controller.offline || !widget.dependencies.session.active,
    child: ListenableBuilder(
      listenable: Listenable.merge([controller, widget.dependencies.session]),
      builder: (context, _) => !widget.dependencies.session.active
          ? const SizedBox.shrink()
          : MessageInboxView(
              title: 'Shop messages',
              rows: [
                for (final e in controller.items)
                  InboxRow(e.id, e.label, e.preview, e.unread, !e.sendAllowed),
              ],
              loading: controller.loading,
              loaded: controller.loaded,
              paging: controller.paging,
              more: controller.trail.next != null,
              unread: controller.unread,
              error: controller.error,
              pageError: controller.pageError,
              coolingDown: controller.coolingDown,
              refresh: controller.load,
              loadMore: () => controller.load(more: true),
              open: (id) async {
                await context.push('/messages/shops/$id');
                if (mounted) controller.load();
              },
            ),
    ),
  );
}

class ShopThreadScreen extends StatefulWidget {
  const ShopThreadScreen({
    super.key,
    required this.dependencies,
    required this.controller,
  });
  final AppDependencies dependencies;
  final ShopThreadController controller;
  @override
  State<ShopThreadScreen> createState() => _ShopThreadScreenState();
}

class _ShopThreadScreenState extends State<ShopThreadScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ForegroundPoll(
      refresh: c.load,
      paused: () => c.offline || !widget.dependencies.session.active,
      child: ListenableBuilder(
        listenable: Listenable.merge([c, widget.dependencies.session]),
        builder: (context, _) => !widget.dependencies.session.active
            ? const SizedBox.shrink()
            : MessageThreadView(
                title: c.conversation?.label ?? 'Shop message',
                rows: [
                  for (final e in c.messages)
                    MessageRow(
                      e.id,
                      e.sequence,
                      e.body,
                      e.mine,
                      e.role,
                      e.at,
                      context: e.context?.label,
                    ),
                ],
                draft: c.pending?.body['body'] as String? ?? c.draft,
                changed: (v) => c.draft = v,
                clearDraft: () => c.draft = '',
                send: c.send,
                retry: c.retry,
                refresh: c.load,
                loadMore: () => c.load(more: true),
                displayed: c.displayed,
                loading: c.loading,
                paging: c.paging,
                sending: c.sending,
                allowed: c.canSend,
                pending: c.pending != null,
                conflict: c.conflict,
                more: c.trail.next != null,
                reviewConflict: c.reviewConflict,
                arrivals: c.arrivals,
                acknowledge: c.acknowledgeArrivals,
                reason: c.conversation?.reason,
                error: c.error,
                pageError: c.pageError,
                readError: c.readError,
                fieldError: c.fieldErrors['body'],
                coolingDown: c.coolingDown,
              ),
      ),
    );
  }
}
