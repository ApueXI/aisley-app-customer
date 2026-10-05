import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/saved/data/legacy_recent_cleanup.dart';
import '../core/ui/marketplace_chrome.dart';
import 'app_dependencies.dart';
import 'router.dart';
import 'theme.dart';

class BuyerScrollBehavior extends MaterialScrollBehavior {
  const BuyerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class BuyerApp extends StatefulWidget {
  const BuyerApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<BuyerApp> createState() => _BuyerAppState();
}

class _BuyerAppState extends State<BuyerApp> with WidgetsBindingObserver {
  late final GoRouter _router = buyerRouter(widget.dependencies);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(removeLegacyRecentHints());
    widget.dependencies.session.bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.dependencies.session.revalidate();
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused) {
      widget.dependencies.session.revalidate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'AISLEY Buyer',
    debugShowCheckedModeBanner: false,
    theme: buyerTheme(),
    themeMode: ThemeMode.light,
    scrollBehavior: const BuyerScrollBehavior(),
    builder: (context, child) => ListenableBuilder(
      listenable: Listenable.merge([
        widget.dependencies.session,
        if (widget.dependencies.commerce != null)
          widget.dependencies.commerce!.cart,
      ]),
      builder: (context, _) => MarketplaceScope(
        active: widget.dependencies.session.active,
        cartCount: widget.dependencies.commerce?.cart.badge,
        child: Column(
          children: [
            if (widget.dependencies.session.revalidationFailure != null)
              _SessionRevalidationNotice(
                onRetry: widget.dependencies.session.revalidate,
                onDismiss:
                    widget.dependencies.session.dismissRevalidationFailure,
              ),
            Expanded(child: child!),
          ],
        ),
      ),
    ),
    routerConfig: _router,
  );
}

class _SessionRevalidationNotice extends StatelessWidget {
  const _SessionRevalidationNotice({
    required this.onRetry,
    required this.onDismiss,
  });
  final VoidCallback onRetry, onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'We could not check your session. This page is still open.',
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(
              tooltip: 'Dismiss session check message',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );
}
