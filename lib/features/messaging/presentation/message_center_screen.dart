import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/foreground_poll.dart';
import '../../../core/ui/list_recovery.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/responsive_layout.dart';
import '../data/conversation_preview.dart';
import 'conversation_tile.dart';

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  late final messages = widget.dependencies.communication!.messages;
  MessageChannel? _filter;

  @override
  void initState() {
    super.initState();
    messages.refresh(automatic: true, onlyNeeded: true);
  }

  @override
  Widget build(BuildContext context) => ForegroundPoll(
    refresh: () => messages.refresh(automatic: true),
    busy: () => messages.busy,
    visible: () =>
        MarketplaceScope.maybeOf(context)?.chatUpdatesManaged != true,
    paused: () =>
        MarketplaceScope.maybeOf(context)?.chatUpdatesManaged == true ||
        !widget.dependencies.session.active,
    child: ListenableBuilder(
      listenable: messages,
      builder: (context, _) {
        if (!widget.dependencies.session.active) return const SizedBox.shrink();
        final channels = messages.channels.entries
            .where((e) => _filter == null || e.key == _filter)
            .toList();
        final rows = messages.conversations(_filter);
        final complete = channels.every(
          (e) => e.value.loaded && !e.value.stale && e.value.error == null,
        );
        final busy = channels.any((e) => e.value.busy);
        final more = channels.any((e) => e.value.trail.next != null);
        final canPage = channels.any(
          (e) =>
              e.value.trail.next != null &&
              !e.value.stale &&
              !e.value.coolingDown &&
              !e.value.busy,
        );
        return ShoppingPage(
          appBar: AppBar(
            title: const Text('Messages'),
            actions: [
              IconButton(
                tooltip: 'Refresh messages',
                onPressed: busy
                    ? null
                    : () => messages.refresh(channel: _filter),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => messages.refresh(channel: _filter),
            child: ListView(
              key: const PageStorageKey('combined-messages'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context),
              children: [
                MarketTabs<MessageChannel?>(
                  values: {
                    null: 'All',
                    for (final channel in MessageChannel.values)
                      channel: channel.filterLabel,
                  },
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 16),
                for (final entry in channels)
                  if (entry.value.busy ||
                      entry.value.stale ||
                      entry.value.error != null ||
                      entry.value.pageError != null)
                    Padding(
                      key: ValueKey('recovery-${entry.key.path}'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.key.label} messages'),
                          ListRecovery(
                            stale: entry.value.stale,
                            retained: entry.value.items.isNotEmpty,
                            busy: entry.value.busy,
                            error: entry.value.error ?? entry.value.pageError,
                            coolingDown: entry.value.coolingDown,
                            retry: () =>
                                entry.value.pageError != null &&
                                    !entry.value.stale
                                ? entry.value.load(more: true)
                                : messages.refresh(channel: entry.key),
                          ),
                        ],
                      ),
                    ),
                if (!busy && complete && rows.isEmpty)
                  const MarketEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No conversations yet.',
                    message:
                        'Open a Shop or an owned Order to start a message.',
                  ),
                for (final row in rows)
                  ConversationTile(
                    key: ValueKey(row.key),
                    row: row,
                    open: () async {
                      await context.push(row.route);
                      if (mounted) {
                        await messages.refresh(channel: row.channel);
                      }
                    },
                  ),
                ListPageAction(
                  hasMore: more,
                  busy: busy,
                  disabled: !canPage,
                  label: 'Load more conversations',
                  load: () => messages.loadMore(_filter),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
