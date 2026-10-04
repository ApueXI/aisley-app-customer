import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../data/notification_models.dart';
import 'notification_controllers.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
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
    builder: (context, _) => !widget.dependencies.session.active
        ? const SizedBox.shrink()
        : ShoppingPage(
            appBar: AppBar(
              title: const Text('Notifications'),
              actions: [
                IconButton(
                  tooltip: 'Refresh notifications',
                  onPressed: controller.loading || controller.coolingDown
                      ? null
                      : controller.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: pagePadding(context),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final status in ['all', 'unread', 'read'])
                        ChoiceChip(
                          label: Text(status),
                          selected: controller.status == status,
                          onSelected: (_) => controller.filter(status),
                        ),
                    ],
                  ),
                  if (controller.loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading notifications',
                    ),
                  if (controller.error != null) ...[
                    Text(controller.error!),
                    TextButton(
                      onPressed: controller.coolingDown
                          ? null
                          : controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                  if (controller.loaded && controller.items.isEmpty)
                    const Text('No notifications in this filter.'),
                  for (final item in controller.items)
                    ListTile(
                      minTileHeight: 72,
                      title: Text(
                        item.title.isEmpty ? 'Notification' : item.title,
                      ),
                      subtitle: Text(
                        '${item.readAt == null ? 'Unread\n' : ''}${item.summary}',
                      ),
                      onTap: () async {
                        await context.push('/notifications/${item.id}');
                        if (mounted) controller.load();
                      },
                    ),
                  if (controller.pageError != null) Text(controller.pageError!),
                  if (controller.hasMore)
                    TextButton(
                      onPressed:
                          controller.loading ||
                              controller.paging ||
                              controller.coolingDown
                          ? null
                          : () => controller.load(more: true),
                      child: const Text('Load more notifications'),
                    ),
                  TextButton(
                    onPressed: () => context.push('/account/preferences'),
                    child: const Text('Promotional preferences'),
                  ),
                ],
              ),
            ),
          ),
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
        appBar: AppBar(title: const Text('Notification')),
        body: SafeArea(
          child: ListView(
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
        ),
      );
    },
  );
}
