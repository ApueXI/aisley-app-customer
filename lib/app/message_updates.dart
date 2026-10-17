import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'message_center.dart';

/// One foreground scheduler serves header badges and mounted channel inboxes.
class MessageUpdates extends StatefulWidget {
  const MessageUpdates({
    super.key,
    required this.messages,
    required this.router,
    required this.child,
  });
  final MessageCenter messages;
  final GoRouter router;
  final Widget child;
  @override
  State<MessageUpdates> createState() => _MessageUpdatesState();
}

class _MessageUpdatesState extends State<MessageUpdates>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true, _enabled = false, _scheduled = false;
  bool _onlyNeeded = true;
  bool get _allowed {
    final configuration = widget.router.routerDelegate.currentConfiguration;
    final path = configuration.isEmpty
        ? widget.router.routeInformationProvider.value.uri.path
        : configuration.last.matchedLocation;
    return _foreground &&
        widget.messages.session.active &&
        !path.startsWith('/policies/');
  }

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.messages.addListener(_sync);
    widget.router.routerDelegate.addListener(_sync);
    _sync();
  }

  void _sync() {
    final allowed = _allowed;
    if (allowed != _enabled) {
      _enabled = allowed;
      _timer?.cancel();
      if (allowed) {
        _timer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (_allowed) unawaited(widget.messages.refresh(automatic: true));
        });
        _scheduleRefresh();
      }
    }
    if (allowed && widget.messages.needsRefresh) {
      _scheduleRefresh(onlyNeeded: true);
    }
  }

  void _scheduleRefresh({bool onlyNeeded = false}) {
    _onlyNeeded = _onlyNeeded && onlyNeeded;
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      final onlyNeeded = _onlyNeeded;
      _onlyNeeded = true;
      _scheduled = false;
      if (mounted && _allowed) {
        unawaited(widget.messages.refresh(onlyNeeded: onlyNeeded));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) widget.messages.markStale();
    _sync();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused && _allowed) _scheduleRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.messages.removeListener(_sync);
    widget.router.routerDelegate.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
