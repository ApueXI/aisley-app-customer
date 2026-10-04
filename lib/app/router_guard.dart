import '../core/security/session_controller.dart';

// Only implemented read destinations can be resumed after authentication.
String safeReturn(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment) {
    return '/account';
  }
  return const ['/', '/shops', '/cart', '/account'].contains(uri.path)
      ? uri.path
      : '/account';
}

String? guardRoute(SessionController session, Uri uri) {
  final target = safeReturn(uri.queryParameters['returnTo']);
  final encoded = Uri.encodeComponent(target);
  final private = const ['/cart', '/account'].contains(uri.path);
  if (private && !session.active) {
    final back = Uri.encodeComponent(uri.path);
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
