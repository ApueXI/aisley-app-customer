import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';

/// Foreground HTTP refresh only. Route visibility, lifecycle and offline failures
/// gate the timer. The owning controller also rejects overlapping requests.
class ForegroundPoll extends StatefulWidget {
  const ForegroundPoll({
    super.key,
    required this.refresh,
    required this.paused,
    this.visible,
    this.busy,
    this.interval = const Duration(seconds: 15),
    this.retryInterval = const Duration(seconds: 30),
    this.recoverable,
    required this.child,
  });
  final Future<void> Function() refresh;
  final bool Function() paused;
  final bool Function()? visible;

  /// Automatic refresh must not supersede a deliberate list/page action.
  final bool Function()? busy;
  final Duration interval, retryInterval;
  final bool Function()? recoverable;
  final Widget child;
  @override
  State<ForegroundPoll> createState() => _ForegroundPollState();
}

class _ForegroundPollState extends State<ForegroundPoll>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true, _refreshing = false;
  bool get _busy => widget.busy?.call() == true;
  bool get _visible =>
      mounted &&
      _foreground &&
      (widget.visible?.call() ?? true) &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (!mounted || !_foreground) return;
    _timer = Timer(
      widget.recoverable?.call() == true
          ? widget.retryInterval
          : widget.interval,
      () => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    if (!_visible || _busy || widget.paused() || _refreshing) {
      if (!_refreshing) _start();
      return;
    }
    _timer?.cancel();
    _refreshing = true;
    try {
      await widget.refresh();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Buyer foreground refresh',
        ),
      );
    } finally {
      _refreshing = false;
      _start();
    }
  }

  void _focusRefresh() {
    // Let the focused button's action establish its busy state first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _start();
      unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused) unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focus) {
      if (!focus || !_visible) return;
      _focusRefresh();
    },
    child: widget.child,
  );
}
