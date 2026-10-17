import 'package:flutter/material.dart';

class MessageAction extends StatelessWidget {
  const MessageAction({
    super.key,
    required this.unread,
    required this.stale,
    required this.onPressed,
  });
  final int? unread;
  final bool stale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('messages-action'),
    tooltip: unread == null
        ? 'Messages, unread status ${stale ? 'may be outdated' : 'unavailable'}'
        : 'Messages, $unread unread',
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: unread == null || unread! > 0,
      label: Text(
        unread == null
            ? '!'
            : unread! > 99
            ? '99+'
            : '$unread',
      ),
      child: const Icon(Icons.chat_bubble_outline),
    ),
  );
}
