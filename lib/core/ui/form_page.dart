import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../networking/api_failure.dart';
import 'responsive_layout.dart';
import 'marketplace_widgets.dart';

class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.dirty = false,
    this.busy = false,
    this.onCancel,
    this.canLeave = true,
    this.maxWidth = 560,
    this.bottomBar,
    this.compact = false,
  });
  final String title;
  final List<Widget> children;
  final bool dirty, busy, canLeave;
  final VoidCallback? onCancel;
  final double maxWidth;
  final Widget? bottomBar;
  final bool compact;
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  bool _allowPop = false;
  Object? _registeredPageKey;
  String? _registeredPath;
  Future<bool>? _pendingExit;
  final Object _registryOwner = Object();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    final routeState = router == null ? null : GoRouterState.of(context);
    final nextKey = routeState?.pageKey;
    final nextPath = routeState?.uri.path;
    if (nextKey == null || _registeredPageKey != null) return;
    _registeredPageKey = nextKey;
    _registeredPath = nextPath;
    FormPageExitRegistry.register(
      nextKey,
      nextPath,
      _registryOwner,
      _confirmRouteExit,
    );
  }

  Future<bool> _confirmRouteExit() {
    if (_allowPop) return Future.value(true);
    final pending = _pendingExit;
    if (pending != null) return pending;
    final request = _confirmRouteExitOnce();
    _pendingExit = request;
    request.whenComplete(() {
      if (identical(_pendingExit, request)) _pendingExit = null;
    });
    return request;
  }

  Future<bool> _confirmRouteExitOnce() async {
    if (!widget.canLeave) return false;
    if (!widget.dirty && !widget.busy) return true;
    final leave = await confirmDiscard(
      context,
      widget.busy
          ? 'A request is in progress. Leaving does not cancel a committed result.'
          : 'Discard the information entered in this form?',
    );
    if (!mounted || !leave) return false;
    setState(() => _allowPop = true);
    return true;
  }

  Future<void> _leave() async {
    if (!await _confirmRouteExit() || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    if (_registeredPageKey case final key?) {
      FormPageExitRegistry.unregister(key, _registryOwner);
    }
    if (_registeredPath case final path?) {
      FormPageExitRegistry.unregisterPath(path, _registryOwner);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.canLeave && (_allowPop || !widget.dirty && !widget.busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: marketplaceAppBar(
        context,
        AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: false,
          leading: widget.canLeave
              ? IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _leave,
                )
              : null,
        ),
        compact: widget.compact,
      ),
      body: SafeArea(
        child: AccountContext(
          child: SingleChildScrollView(
            padding: pagePadding(context),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Material(
                  color: widget.maxWidth <= 560
                      ? Colors.white
                      : Colors.transparent,
                  shape: widget.maxWidth <= 560
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        )
                      : null,
                  child: Padding(
                    padding: widget.maxWidth <= 560
                        ? const EdgeInsets.all(24)
                        : EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children
                          .map(
                            (child) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: child,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: ContentViewport(
                shrinkWrap: true,
                child: widget.bottomBar!,
              ),
            ),
    ),
  );
}

typedef FormPageExitCallback = Future<bool> Function();

class _RegisteredFormExit {
  const _RegisteredFormExit(this.owner, this.callback);
  final Object owner;
  final FormPageExitCallback callback;
}

/// Associates an active FormPage's unsaved-input guard with its GoRouter page.
/// The app's route-entry guard consults this registry before moving away.
class FormPageExitRegistry {
  FormPageExitRegistry._();

  static final Map<Object, _RegisteredFormExit> _guards = {};
  static final Map<String, _RegisteredFormExit> _guardsByPath = {};

  static void register(
    Object pageKey,
    String? path,
    Object owner,
    FormPageExitCallback callback,
  ) {
    final registration = _RegisteredFormExit(owner, callback);
    _guards[pageKey] = registration;
    if (path != null) _guardsByPath[path] = registration;
  }

  static void unregister(Object pageKey, Object owner) {
    if (_guards[pageKey]?.owner == owner) _guards.remove(pageKey);
  }

  static void unregisterPath(String path, Object owner) {
    if (_guardsByPath[path]?.owner == owner) _guardsByPath.remove(path);
  }

  static _RegisteredFormExit? _registrationFor(GoRouterState state) =>
      _guards[state.pageKey] ?? _guardsByPath[state.uri.path];

  static bool hasGuard(GoRouterState state) => _registrationFor(state) != null;

  static Future<bool> allowExit(GoRouterState state) {
    final registration = _registrationFor(state);
    return registration?.callback() ?? Future.value(true);
  }
}

bool validateForm(FormState form) {
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;
  final field = invalid.first;
  FocusNode? node;
  void findInput(Element element) {
    final widget = element.widget;
    if (widget is TextField) node = widget.focusNode;
    if (widget is DropdownButton<String>) node = widget.focusNode;
    if (node == null) element.visitChildren(findInput);
  }

  (field.context as Element).visitChildren(findInput);
  node?.requestFocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (field.mounted) Scrollable.ensureVisible(field.context, alignment: 0.2);
  });
  return false;
}

Future<bool> confirmDiscard(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Leave this screen?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class FailureNotice extends StatelessWidget {
  const FailureNotice(this.failure, {super.key});
  final ApiFailure failure;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      failure.description,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String? requiredText(String? value, {int max = 255}) =>
    value == null || value.trim().isEmpty
    ? 'Enter a value.'
    : value.length > max
    ? 'Use at most $max characters.'
    : null;
String? emailError(String? value) {
  final error = requiredText(value);
  if (error != null) return error;
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
      ? null
      : 'Enter a valid email.';
}

String? passwordError(String? value) =>
    value == null ||
        value.length < 8 ||
        !RegExp('[a-z]').hasMatch(value) ||
        !RegExp('[A-Z]').hasMatch(value) ||
        !RegExp('[0-9]').hasMatch(value)
    ? 'Use 8 or more characters, mixed case and a number.'
    : null;
