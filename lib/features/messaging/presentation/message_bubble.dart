import 'package:flutter/material.dart';

import 'message_row.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.row});
  final MessageRow row;
  @override
  Widget build(BuildContext context) => Align(
    alignment: row.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: row.mine ? const Color(0xFFFCE8F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.mine ? 'You' : row.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SelectableText(row.body),
          if (row.context != null) Text(row.context!),
          if (row.at != null)
            Text(
              row.at!.toLocal().toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );
}
