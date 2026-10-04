import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/saved/data/legacy_recent_cleanup.dart';
import 'app_dependencies.dart';
import 'router.dart';
import 'theme.dart';

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
      widget.dependencies.session.refresh();
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
    routerConfig: _router,
  );
}
