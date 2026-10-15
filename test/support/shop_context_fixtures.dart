import 'fakes.dart';

Map<String, dynamic> shopContext({
  String shop = otherId,
  String? conversation,
  String availability = 'online',
  bool allowed = true,
}) => {
  'shop': {
    'id': shop,
    'name': 'Synthetic Shop',
    'slug': null,
    'availability': availability,
  },
  'conversation_id': conversation,
  'send_allowed': allowed,
};

Map<String, dynamic> shopSummary({
  String id = customerId,
  String shop = otherId,
  String availability = 'online',
  bool allowed = true,
}) => {
  ...fixture('chat-messaging', 'op-059')['data'] as Map<String, dynamic>,
  'id': id,
  'shop': shopContext(shop: shop, availability: availability)['shop'],
  'send_allowed': allowed,
};

Map<String, dynamic> shopWrite({String shop = otherId}) => {
  'conversation': shopSummary(shop: shop),
  'message': fixture('chat-messaging', 'op-058')['message'],
};
