import '../../../core/chat_media/attachment.dart';

class MessageRow {
  const MessageRow(
    this.id,
    this.sequence,
    this.body,
    this.mine,
    this.label,
    this.at, {
    this.context,
    this.attachments = const [],
  });
  final String id, body, label;
  final int sequence;
  final bool mine;
  final DateTime? at;
  final String? context;
  final List<ChatAttachment> attachments;
}
