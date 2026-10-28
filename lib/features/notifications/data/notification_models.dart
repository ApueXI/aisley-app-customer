import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/commerce/commerce_value.dart';

class NotificationCategory {
  const NotificationCategory({required this.key, required this.label});

  final String key;
  final String label;

  factory NotificationCategory.fromJson(Object? json) {
    final wire = Wire(json);
    return NotificationCategory(
      key: wire.string('key'),
      label: wire.string('label'),
    );
  }
}

const buyerNotificationCategories = <NotificationCategory>[
  NotificationCategory(key: 'orders', label: 'Orders'),
  NotificationCategory(key: 'support', label: 'Support'),
  NotificationCategory(key: 'promotions', label: 'Promotions'),
  NotificationCategory(key: 'announcements', label: 'Announcements'),
  NotificationCategory(key: 'questions-reviews', label: 'Questions & reviews'),
  NotificationCategory(key: 'other', label: 'Other'),
];

List<NotificationCategory> buyerNotificationCategoryCatalog(Object? raw) {
  if (raw == null) return buyerNotificationCategories;
  if (raw is! List) throw const ApiFailure(FailureKind.decode);

  final knownKeys = buyerNotificationCategories.map((item) => item.key).toSet();
  final labels = <String, String>{};
  for (final value in raw) {
    final category = NotificationCategory.fromJson(value);
    if (knownKeys.contains(category.key) && category.key != 'other') {
      labels[category.key] = category.label;
    }
  }
  return List<NotificationCategory>.unmodifiable(
    buyerNotificationCategories.map(
      (category) => category.key == 'other'
          ? category
          : NotificationCategory(
              key: category.key,
              label: labels[category.key] ?? category.label,
            ),
    ),
  );
}

class BuyerNotificationPage {
  const BuyerNotificationPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.categories,
  });

  final List<BuyerNotification> items;
  final int page;
  final bool hasMore;
  final List<NotificationCategory> categories;
}

class BuyerNotification {
  BuyerNotification.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    type = w.string('type');
    title = w.string('title');
    summary = w.string('summary');
    orderId = nullableUuid(w, 'order_id');
    orderReference = w.nullableString('order_reference');
    status = w.nullableString('status');
    readAt = w.timestamp('read_at');
    createdAt = w.timestamp('created_at');
    resourceType = w.nullableString('resource_type');
    resourceId = w.nullableString('resource_id');
    productId = nullableUuid(w, 'product_id');
    destination = w.nullableString('destination');
    final rawCategory = w.optionalString('category');
    category =
        buyerNotificationCategories.any((value) => value.key == rawCategory)
        ? rawCategory!
        : 'other';
    final rawLabel = w.optionalString('category_label');
    categoryLabel = category == 'other'
        ? 'Other'
        : (rawLabel?.trim().isNotEmpty ?? false)
        ? rawLabel!.trim()
        : buyerNotificationCategories
              .firstWhere((value) => value.key == category)
              .label;
  }
  late final String id, type, title, summary, category, categoryLabel;
  late final String? orderId,
      orderReference,
      status,
      resourceType,
      destination,
      resourceId,
      productId;
  late final DateTime? readAt, createdAt;
}

String notificationDestination(BuyerNotification notification) {
  final fallback = '/notifications/${notification.id}';
  const supportTypes = <String>{
    'support-ticket.created',
    'support-ticket.requester-replied',
    'support-ticket.admin-replied',
    'support-ticket.status-changed',
  };
  final ticketId = notification.resourceId;
  if (supportTypes.contains(notification.type) &&
      notification.resourceType == 'support_ticket' &&
      ticketId != null &&
      validUuid(ticketId) &&
      notification.destination == '/account/support-tickets?ticket=$ticketId') {
    return '/support-tickets/$ticketId';
  }

  final destination = notification.destination;
  if (destination == null || destination.trim().isEmpty) return fallback;
  final uri = Uri.tryParse(destination);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.path.contains('%') ||
      uri.path.contains('\\')) {
    return fallback;
  }
  final parts = uri.path.split('/').where((e) => e.isNotEmpty).toList();
  if (parts.length == 2 && parts[0] == 'products' && validUuid(parts[1])) {
    if (uri.fragment == 'questions' || uri.fragment == 'qa') {
      return '/products/${parts[1]}/questions';
    }
    if (uri.fragment == 'reviews') return '/products/${parts[1]}/reviews';
    return uri.hasFragment ? fallback : '/products/${parts[1]}';
  }
  if (parts.length == 2 &&
      parts[0] == 'shops' &&
      !uri.hasFragment &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,254}$').hasMatch(parts[1])) {
    return '/shops/${parts[1]}';
  }
  if (parts.length == 2 &&
      parts[0] == 'orders' &&
      validUuid(parts[1]) &&
      !uri.hasFragment) {
    return '/orders/${parts[1]}';
  }
  if (parts.length == 3 &&
      parts[0] == 'account' &&
      parts[1] == 'orders' &&
      validUuid(parts[2]) &&
      !uri.hasFragment) {
    return '/orders/${parts[2]}';
  }
  return fallback;
}
