import 'package:flutter/material.dart';

import 'message_row.dart';
import '../../../core/chat_media/draft_controller.dart';
import '../../../core/chat_media/image_widgets.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.row, this.media});
  final MessageRow row;
  final ChatMediaDraftController? media;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: row.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: (constraints.maxWidth * .9).clamp(0, 640),
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: row.mine ? const Color(0xFFFCE8F2) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(row.mine ? 8 : 2),
            bottomRight: Radius.circular(row.mine ? 2 : 8),
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.mine ? 'You' : row.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(row.body),
            if (media != null)
              for (final attachment in row.attachments)
                PrivateChatImage(
                  key: ValueKey(attachment.id),
                  attachment: attachment,
                  controller: media!,
                ),
            if (row.context != null) ...[
              const SizedBox(height: 8),
              Text(row.context!),
            ],
            if (row.at != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  row.at!.toLocal().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
