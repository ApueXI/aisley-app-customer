import '../core/security/session_controller.dart';
import 'discovery_route_query.dart';
import '../core/commerce/commerce_value.dart';

// Only implemented read destinations can be resumed after authentication.
String safeReturn(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
    return '/account';
  }
  if (uri.path == '/search' &&
      DiscoveryRouteQuery.parse(uri, kind: 'search').valid) {
    return uri.toString();
  }
  if (uri.path == '/shops' &&
      DiscoveryRouteQuery.parse(uri, kind: 'directory').valid) {
    return uri.toString();
  }
  if (RegExp(r'^/shops/[A-Za-z0-9][A-Za-z0-9_-]{0,254}$').hasMatch(uri.path) &&
      DiscoveryRouteQuery.parse(uri, kind: 'shop').valid) {
    return uri.toString();
  }
  if (safeCommunicationReturn(uri)) return uri.toString();
  if (uri.path == '/checkout' && !uri.hasQuery) return '/cart';
  if (uri.hasQuery) return '/account';
  if (const [
        '/',
        '/cart',
        '/orders',
        '/account',
        '/account/profile',
        '/account/password',
        '/account/photo',
        '/account/preferences',
        '/account/addresses',
        '/account/wishlist',
        '/account/recently-viewed',
      ].contains(uri.path) ||
      RegExp(
        r'^/products/[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
      ).hasMatch(uri.path) ||
      RegExp(
        r'^/(?:orders|checkout/result)/[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
      ).hasMatch(uri.path)) {
    return uri.path;
  }
  return '/account';
}

String? guardRoute(SessionController session, Uri uri) {
  final target = safeReturn(uri.queryParameters['returnTo']);
  final encoded = Uri.encodeComponent(target);
  final private =
      uri.path.startsWith('/messages/') ||
      uri.path == '/notifications' ||
      uri.path.startsWith('/notifications/') ||
      uri.path == '/support-tickets' ||
      uri.path.startsWith('/support-tickets/') ||
      uri.path.startsWith('/order-items/') ||
      uri.path == '/cart' ||
      uri.path == '/orders' ||
      uri.path.startsWith('/orders/') ||
      uri.path == '/checkout' ||
      uri.path.startsWith('/checkout/') ||
      uri.path == '/account' ||
      uri.path.startsWith('/account/');
  if (private && !session.active) {
    final back = Uri.encodeComponent(safeReturn(uri.toString()));
    return switch (session.phase) {
      SessionPhase.signedOut ||
      SessionPhase.accountDenied => '/login?returnTo=$back',
      SessionPhase.consentRequired => '/consent?returnTo=$back',
      _ => '/session?returnTo=$back',
    };
  }
  if (session.active &&
      const ['/login', '/session', '/consent'].contains(uri.path)) {
    return target;
  }
  if (uri.path == '/session' &&
      const [
        SessionPhase.signedOut,
        SessionPhase.accountDenied,
      ].contains(session.phase)) {
    return '/login?returnTo=$encoded';
  }
  if (uri.path == '/consent') {
    if (session.customer == null) return '/session?returnTo=$encoded';
    if (session.phase == SessionPhase.consentUnavailable ||
        session.phase == SessionPhase.identityUnavailable) {
      return '/session?returnTo=$encoded';
    }
  }
  return null;
}

bool safeCommunicationReturn(Uri uri) {
  if (uri.hasFragment || uri.hasScheme || uri.hasAuthority) return false;
  final p = uri.path.split('/').where((e) => e.isNotEmpty).toList();
  if (!uri.hasQuery &&
      const [
        '/messages/shops',
        '/messages/logistics',
        '/messages/courier',
        '/notifications',
        '/support-tickets',
        '/support-tickets/new',
      ].contains(uri.path)) {
    return true;
  }
  if (!uri.hasQuery &&
      p.length == 2 &&
      const ['notifications', 'support-tickets'].contains(p[0]) &&
      validUuid(p[1])) {
    return true;
  }
  if (!uri.hasQuery &&
      p.length == 3 &&
      p[0] == 'products' &&
      validUuid(p[1]) &&
      const ['questions', 'reviews'].contains(p[2])) {
    return true;
  }
  if (!uri.hasQuery &&
      p.length == 3 &&
      p[0] == 'messages' &&
      const ['shops', 'logistics', 'courier'].contains(p[1]) &&
      validUuid(p[2])) {
    return true;
  }
  if (!uri.hasQuery &&
      p.length == 4 &&
      p[0] == 'messages' &&
      const ['logistics', 'courier'].contains(p[1]) &&
      p[2] == 'order' &&
      validUuid(p[3])) {
    return true;
  }
  if (!uri.hasQuery &&
      p.length == 4 &&
      p[0] == 'order-items' &&
      validUuid(p[1]) &&
      p[2] == 'review' &&
      validUuid(p[3])) {
    return true;
  }
  if (p.length == 4 &&
      p[0] == 'messages' &&
      p[1] == 'shops' &&
      p[2] == 'new' &&
      validUuid(p[3])) {
    if (!uri.hasQuery) return true;
    return uri.queryParametersAll.values.every((v) => v.length == 1) &&
        uri.queryParameters.keys.every(
          (k) => const ['context_type', 'context_id'].contains(k),
        ) &&
        const [
          'product',
          'order',
        ].contains(uri.queryParameters['context_type']) &&
        validUuid(uri.queryParameters['context_id'] ?? '');
  }
  return false;
}
