import 'package:flutter/material.dart';

import '../data/conversation_preview.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.row, required this.open});
  final ConversationPreview row;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    final at = row.at?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        minTileHeight: 80,
        leading: Icon(
          row.readOnly ? Icons.lock_outline : Icons.chat_bubble_outline,
        ),
        title: Text(
          row.label,
          style: TextStyle(
            fontWeight: row.unread > 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                row.channel.label,
                if (row.reference != null) row.reference!,
              ].join(' · '),
            ),
            if (row.preview != null && row.preview!.isNotEmpty)
              Text(row.preview!, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (at != null)
              Text(
                '${localizations.formatShortDate(at)} '
                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
              ),
            if (row.unread > 0) Text('${row.unread} unread'),
            if (row.readOnly) const Text('Read only'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}
