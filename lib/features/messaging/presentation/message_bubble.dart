import 'package:flutter/material.dart';

import 'message_row.dart';
import '../../../core/chat_media/draft_controller.dart';
import '../../../core/chat_media/image_widgets.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.row,
    this.media,
    this.conversationStyle = false,
  });
  final MessageRow row;
  final ChatMediaDraftController? media;
  final bool conversationStyle;
  @override
  Widget build(BuildContext context) => conversationStyle
      ? _conversation(context)
      : LayoutBuilder(
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
                        '${MaterialLocalizations.of(context).formatShortDate(row.at!.toLocal())} '
                        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(row.at!.toLocal()))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

  Widget _conversation(BuildContext context) {
    final theme = Theme.of(context);
    final ink = row.mine ? Colors.white : theme.colorScheme.onSurface;
    final at = row.at?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final timestamp = at == null
        ? null
        : '${localizations.formatShortDate(at)} · '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: row.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (constraints.maxWidth * .9).clamp(0, 640),
          ),
          child: Column(
            crossAxisAlignment: row.mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                [row.mine ? 'You' : row.label, ?timestamp].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: row.mine ? theme.colorScheme.secondary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: row.mine
                      ? null
                      : Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: ink),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.body.isNotEmpty)
                        SelectableText(row.body, style: TextStyle(color: ink)),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
