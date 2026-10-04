import '../core/security/session_controller.dart';
import 'discovery_route_query.dart';

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
  if (uri.hasQuery) return '/account';
  if (const [
        '/',
        '/cart',
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
      ).hasMatch(uri.path)) {
    return uri.path;
  }
  return '/account';
}

String? guardRoute(SessionController session, Uri uri) {
  final target = safeReturn(uri.queryParameters['returnTo']);
  final encoded = Uri.encodeComponent(target);
  final private =
      uri.path == '/cart' ||
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
