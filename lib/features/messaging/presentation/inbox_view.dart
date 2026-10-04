import 'package:flutter/material.dart';

import '../../../core/ui/responsive_layout.dart';

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
  });
  final String title;
  final List<InboxRow> rows;
  final bool loading, loaded, paging, more, coolingDown;
  final int unread;
  final String? error, pageError;
  final VoidCallback refresh, loadMore;
  final void Function(String) open;
  @override
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'Refresh inbox',
          onPressed: loading || paging || coolingDown ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: pagePadding(context),
      children: [
        if (loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading messages'),
        if (error != null) ...[
          Semantics(liveRegion: true, child: Text(error!)),
          TextButton(
            onPressed: coolingDown ? null : refresh,
            child: const Text('Retry'),
          ),
        ],
        Text('$unread unread in this channel'),
        if (loaded && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No conversations yet. Open a Shop or an owned Order to start a message.',
            ),
          ),
        for (final row in rows)
          ListTile(
            minTileHeight: 72,
            title: Text(row.label),
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
        if (pageError != null) Text(pageError!),
        if (more)
          TextButton(
            onPressed: paging || loading || coolingDown ? null : loadMore,
            child: Text(paging ? 'Loading…' : 'Load more conversations'),
          ),
      ],
    ),
  );
}
