import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';

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
    destination = w.string('destination');
  }
  late final String id, type, title, summary, destination;
  late final String? orderId,
      orderReference,
      status,
      resourceType,
      resourceId,
      productId;
  late final DateTime? readAt, createdAt;
}

String notificationDestination(BuyerNotification notification) {
  final fallback = '/notifications/${notification.id}';
  final uri = Uri.tryParse(notification.destination);
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
