import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/list_recovery.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import '../data/notification_models.dart';
import 'notification_controllers.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({
    super.key,
    required this.dependencies,
    this.embedded = false,
  });
  final AppDependencies dependencies;
  final bool embedded;
  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  late final controller = NotificationInboxController(
    widget.dependencies.session,
    widget.dependencies.communication!.notifications,
  );
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, widget.dependencies.session]),
    builder: (context, _) {
      if (!widget.dependencies.session.active) return const SizedBox.shrink();
      final content = _content(context);
      if (widget.embedded) return content;
      return ShoppingPage(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (!marketplaceDesktop(context)) ...marketplaceActions(context),
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed: controller.loading || controller.coolingDown
                  ? null
                  : controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: content,
      );
    },
  );

  Widget _content(BuildContext context) => ListView(
    padding: pagePadding(context),
    children: [
      if (widget.embedded)
        MarketPageHeading(
          title: 'Notifications',
          subtitle: 'Updates for your Buyer account',
          action: IconButton(
            tooltip: 'Refresh notifications',
            onPressed: controller.loading || controller.coolingDown
                ? null
                : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ),
      MarketTabs<String>(
        values: const {'all': 'All', 'unread': 'Unread', 'read': 'Read'},
        selected: controller.status,
        onSelected: controller.filter,
      ),
      const SizedBox(height: 12),
      Text('Category', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilterChip(
            key: const ValueKey('notification-category-all'),
            label: const Text('All categories'),
            selected: controller.category == 'all',
            onSelected: (_) => controller.setCategory('all'),
          ),
          for (final category in controller.categories)
            FilterChip(
              key: ValueKey('notification-category-${category.key}'),
              label: Text(category.label),
              selected: controller.category == category.key,
              onSelected: (_) => controller.setCategory(category.key),
            ),
        ],
      ),
      const SizedBox(height: 8),
      ListRecovery(
        stale: controller.stale,
        retry: controller.load,
        error: controller.error,
        retained: controller.items.isNotEmpty,
        busy: controller.loading,
        coolingDown: controller.coolingDown,
      ),
      if (controller.loaded &&
          !controller.stale &&
          !controller.loading &&
          controller.error == null &&
          controller.pageError == null &&
          controller.items.isEmpty)
        const MarketEmptyState(
          icon: Icons.notifications_none,
          title: 'No notifications in this filter.',
        ),
      for (final item in controller.items)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: item.readAt == null ? const Color(0xFFFFF0F6) : Colors.white,
          child: ListTile(
            minTileHeight: 72,
            leading: Icon(
              item.readAt == null
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined,
            ),
            title: Text(
              item.title.isEmpty ? 'Notification' : item.title,
              style: TextStyle(
                fontWeight: item.readAt == null
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(item.categoryLabel)),
                    Text(item.readAt == null ? 'Unread' : 'Read'),
                  ],
                ),
                Text(item.summary),
                if (item.createdAt != null)
                  Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(item.createdAt!.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            onTap: () async {
              await context.push('/notifications/${item.id}');
              if (mounted) controller.load();
            },
          ),
        ),
      ListPageAction(
        load: () => controller.load(more: true),
        hasMore: controller.hasMore,
        error: controller.pageError,
        busy: controller.paging,
        disabled:
            controller.loading || controller.stale || controller.coolingDown,
        label: 'Load more notifications',
      ),
    ],
  );
}

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.dependencies,
    required this.id,
  });
  final AppDependencies dependencies;
  final String id;
  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late final controller = NotificationDetailController(
    widget.dependencies.session,
    widget.dependencies.communication!.notifications,
    widget.id,
  );
  bool _displayScheduled = false;
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, widget.dependencies.session]),
    builder: (context, _) {
      if (!widget.dependencies.session.active) return const SizedBox.shrink();
      final item = controller.value;
      if (item != null &&
          !_displayScheduled &&
          !controller.loading &&
          controller.readError == null) {
        _displayScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            controller.displayed();
          }
        });
      }
      final target = item == null ? null : notificationDestination(item);
      return ShoppingPage(
        appBar: AppBar(
          title: const Text('Notification'),
          actions: [
            if (!marketplaceDesktop(context)) ...marketplaceActions(context),
          ],
        ),
        body: ListView(
          padding: pagePadding(context),
          children: [
            if (controller.loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Loading notification',
              ),
            if (controller.error != null) Text(controller.error!),
            if (item != null) ...[
              Text(
                item.title.isEmpty ? 'Notification' : item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SelectableText(item.summary),
              Chip(label: Text(item.categoryLabel)),
              if (item.createdAt != null)
                Text(item.createdAt!.toLocal().toString()),
              Text(item.readAt == null ? 'Unread' : 'Read'),
              if (item.orderReference != null) Text(item.orderReference!),
              if (target != '/notifications/${item.id}')
                FilledButton(
                  onPressed: () => context.push(target!),
                  child: const Text('Open related content'),
                )
              else
                const Text(
                  'Related destination is unavailable. This notification remains readable.',
                ),
            ],
            if (controller.readError != null) ...[
              Text(controller.readError!),
              TextButton(
                onPressed: controller.reading || controller.coolingDown
                    ? null
                    : controller.displayed,
                child: const Text('Retry marking read'),
              ),
            ],
            TextButton(
              onPressed: controller.loading || controller.coolingDown
                  ? null
                  : controller.load,
              child: const Text('Retry / refresh'),
            ),
          ],
        ),
      );
    },
  );
}
