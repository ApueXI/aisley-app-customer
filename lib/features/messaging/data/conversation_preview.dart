enum MessageChannel {
  shop('Shops', 'Shop / Seller', 'shops'),
  logistics('Logistics', 'Logistics', 'logistics'),
  courier('Courier', 'Courier', 'courier');

  const MessageChannel(this.filterLabel, this.label, this.path);
  final String filterLabel, label, path;
}

/// A display projection only; channel DTOs retain permissions and read state.
class ConversationPreview {
  const ConversationPreview({
    required this.channel,
    required this.id,
    required this.label,
    required this.preview,
    required this.at,
    required this.unread,
    required this.readOnly,
    this.reference,
  });
  final MessageChannel channel;
  final String id, label;
  final String? preview, reference;
  final DateTime? at;
  final int unread;
  final bool readOnly;
  String get key => '${channel.path}/$id';
  String get route => '/messages/$key';

  static int compare(ConversationPreview a, ConversationPreview b) {
    final time = a.at == null
        ? (b.at == null ? 0 : 1)
        : b.at == null
        ? -1
        : b.at!.compareTo(a.at!);
    if (time != 0) return time;
    final channel = a.channel.index.compareTo(b.channel.index);
    return channel != 0 ? channel : a.id.compareTo(b.id);
  }
}
