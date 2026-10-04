import 'dart:async';

import 'package:flutter/material.dart';

/// Foreground HTTP refresh only. Route visibility, lifecycle and offline failures
/// gate the timer. The owning controller also rejects overlapping requests.
class ForegroundPoll extends StatefulWidget {
  const ForegroundPoll({
    super.key,
    required this.refresh,
    required this.paused,
    this.visible,
    required this.child,
  });
  final Future<void> Function() refresh;
  final bool Function() paused;
  final bool Function()? visible;
  final Widget child;
  @override
  State<ForegroundPoll> createState() => _ForegroundPollState();
}

class _ForegroundPollState extends State<ForegroundPoll>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  bool get _visible =>
      mounted &&
      _foreground &&
      (widget.visible?.call() ?? true) &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_visible && !widget.paused()) unawaited(widget.refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _start();
      if (_visible) unawaited(widget.refresh());
    } else {
      _timer?.cancel();
    }
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
      if (focus && _visible) unawaited(widget.refresh());
    },
    child: widget.child,
  );
}
