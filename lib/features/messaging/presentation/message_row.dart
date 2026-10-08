class MessageRow {
  const MessageRow(
    this.id,
    this.sequence,
    this.body,
    this.mine,
    this.label,
    this.at, {
    this.context,
  });
  final String id, body, label;
  final int sequence;
  final bool mine;
  final DateTime? at;
  final String? context;
}
