import 'package:dio/dio.dart';

import 'fakes.dart';

Map<String, dynamic> inboxPage(
  String channel, {
  String id = customerId,
  int unread = 1,
  String? next,
  String? at = '2026-10-17T08:00:00Z',
  String? label,
}) {
  final shop = channel == 'shop';
  final page = fixture(
    shop ? 'chat-messaging' : '$channel-messaging',
    shop
        ? 'op-057'
        : channel == 'logistics'
        ? 'op-064'
        : 'op-070',
  );
  final row =
      (page[shop ? 'items' : 'data'] as List).first as Map<String, dynamic>;
  row['id'] = id;
  row['last_message_at'] = at;
  row['unread_count'] = unread;
  if (label != null) {
    if (shop) {
      row['shop']['name'] = label;
    } else {
      row['counterparty_label'] = label;
    }
  }
  final meta = shop ? page : page['meta'] as Map<String, dynamic>;
  meta['unread_count'] = unread;
  meta['next_cursor'] = next;
  return page;
}

String channelFor(RequestOptions o) =>
    o.uri.path.contains('logistics-conversations')
    ? 'logistics'
    : o.uri.path.contains('courier-conversations')
    ? 'courier'
    : 'shop';
