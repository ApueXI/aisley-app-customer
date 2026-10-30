import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/foreground_poll.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../messaging/presentation/message_views.dart';
import 'shop_thread_controller.dart';
import '../data/shop_models.dart';

class ShopInboxScreen extends StatefulWidget {
  const ShopInboxScreen({
    super.key,
    required this.dependencies,
    this.embedded = false,
  });
  final AppDependencies dependencies;
  final bool embedded;
  @override
  State<ShopInboxScreen> createState() => _ShopInboxScreenState();
}

class _ShopInboxScreenState extends State<ShopInboxScreen> {
  late final controller = widget.dependencies.communication!.shopInbox;
  @override
  void initState() {
    super.initState();
    if (!controller.loaded) controller.load();
  }

  @override
  Widget build(BuildContext context) => ForegroundPoll(
    refresh: () => controller.load(retain: true),
    busy: () => controller.loading || controller.paging,
    visible: () =>
        MarketplaceScope.maybeOf(context)?.chatUpdatesManaged != true &&
        (!widget.embedded || marketplaceDesktop(context)),
    paused: () =>
        MarketplaceScope.maybeOf(context)?.chatUpdatesManaged == true ||
        controller.offline ||
        !widget.dependencies.session.active ||
        widget.embedded && !marketplaceDesktop(context),
    child: ListenableBuilder(
      listenable: Listenable.merge([controller, widget.dependencies.session]),
      builder: (context, _) => !widget.dependencies.session.active
          ? const SizedBox.shrink()
          : MessageInboxView(
              title: 'Shop messages',
              embedded: widget.embedded,
              rows: [
                for (final e in controller.items)
                  InboxRow(e.id, e.label, e.preview, e.unread, !e.sendAllowed),
              ],
              loading: controller.loading,
              stale: controller.stale,
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
      refresh: c.refresh,
      interval: const Duration(seconds: 5),
      retryInterval: const Duration(seconds: 30),
      recoverable: () => c.offline || c.refreshError != null,
      busy: () =>
          c.loading || c.refreshing || c.paging || c.sending || c.coolingDown,
      paused: () => !widget.dependencies.session.active || c.unavailable,
      child: ListenableBuilder(
        listenable: Listenable.merge([c, widget.dependencies.session]),
        builder: (context, _) => !widget.dependencies.session.active
            ? const SizedBox.shrink()
            : MessageThreadView(
                compactComposer: true,
                inbox: widget.dependencies.communication == null
                    ? null
                    : ShopInboxScreen(
                        dependencies: widget.dependencies,
                        embedded: true,
                      ),
                title: c.shop?.name ?? 'Shop message',
                subtitle:
                    'Shop messages · ${c.shop?.availability.label ?? 'Checking Shop'}',
                media: c.media,
                mediaContext: c.mediaContext,
                contextAction: _contextCard(context, _latestContext(c)),
                rows: [
                  for (final e in c.messages)
                    MessageRow(
                      e.id,
                      e.sequence,
                      e.body,
                      e.mine,
                      e.role,
                      e.at,
                      attachments: e.attachments,
                      context: e.context?.label,
                    ),
                ],
                draft: c.pending?.body['body'] as String? ?? c.draft,
                changed: (v) => c.draft = v,
                clearDraft: () {
                  c.draft = '';
                  c.media?.clear();
                },
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
                reason: c.sendReason,
                error: c.error ?? c.refreshError,
                pageError: c.pageError,
                readError: c.readError,
                fieldError: c.fieldErrors['body'],
                coolingDown: c.coolingDown,
              ),
      ),
    );
  }

  ShopMessageContext? _latestContext(ShopThreadController controller) {
    for (final message in controller.messages.reversed) {
      if (message.context != null) return message.context;
    }
    return null;
  }

  Widget? _contextCard(BuildContext context, ShopMessageContext? value) {
    if (value == null) return null;
    final type = value.type.toLowerCase();
    final route = value.id == null
        ? null
        : switch (type) {
            'product' => '/products/${value.id}',
            'order' => '/orders/${value.id}',
            _ => null,
          };
    final action = route == null
        ? null
        : TextButton(
            onPressed: () => context.push(route),
            child: Text(type == 'order' ? 'View Order' : 'View product'),
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    type == 'order'
                        ? Icons.receipt_long_outlined
                        : Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(value.label)),
              ],
            );
            if (action == null) return details;
            if (constraints.maxWidth < 300 * catalogTextScale(context)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, action],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 8),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
