import 'package:flutter/material.dart';

import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/list_recovery.dart';
import '../../../core/ui/marketplace_surfaces.dart';

class InboxRow {
  const InboxRow(this.id, this.label, this.preview, this.unread, this.readOnly);
  final String id, label;
  final String? preview;
  final int unread;
  final bool readOnly;
}

class MessageInboxView extends StatelessWidget {
  const MessageInboxView({
    super.key,
    required this.title,
    required this.rows,
    required this.loading,
    required this.loaded,
    required this.paging,
    required this.more,
    required this.refresh,
    required this.loadMore,
    required this.open,
    this.error,
    this.pageError,
    this.unread = 0,
    this.coolingDown = false,
    this.embedded = false,
    this.stale = false,
  });
  final String title;
  final bool embedded, stale;
  final List<InboxRow> rows;
  final bool loading, loaded, paging, more, coolingDown;
  final int unread;
  final String? error, pageError;
  final VoidCallback refresh, loadMore;
  final void Function(String) open;
  @override
  Widget build(BuildContext context) {
    if (embedded) return _list(context);
    return ShoppingPage(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh inbox',
            onPressed: loading || coolingDown ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            key: const ValueKey('inbox-list'),
            flex: marketplaceDesktop(context) ? 1 : 3,
            child: _list(context),
          ),
          if (marketplaceDesktop(context))
            const Expanded(
              flex: 2,
              child: Center(
                child: Text('Choose a conversation to read or reply.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) => ListView(
    padding: pagePadding(context),
    children: [
      ListRecovery(
        stale: stale,
        retry: refresh,
        error: error,
        retained: rows.isNotEmpty,
        busy: loading,
        coolingDown: coolingDown,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '$unread unread in this channel',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      if (loaded &&
          !loading &&
          !stale &&
          error == null &&
          pageError == null &&
          rows.isEmpty)
        const MarketEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No conversations yet.',
          message: 'Open a Shop or an owned Order to start a message.',
        ),
      for (final row in rows)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            minTileHeight: 72,
            leading: Icon(
              row.readOnly ? Icons.lock_outline : Icons.chat_bubble_outline,
            ),
            title: Text(
              row.label,
              style: TextStyle(
                fontWeight: row.unread > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            subtitle: Text(
              [
                if (row.unread > 0) '${row.unread} unread',
                if (row.readOnly) 'Read only',
                if (row.preview != null) row.preview!,
              ].join('\n'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(row.id),
          ),
        ),
      ListPageAction(
        load: loadMore,
        hasMore: more,
        error: pageError,
        busy: paging,
        disabled: loading || stale || coolingDown,
        label: 'Load more conversations',
      ),
    ],
  );
}
