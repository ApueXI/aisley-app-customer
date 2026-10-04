import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../networking/api_failure.dart';

class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.dirty = false,
    this.busy = false,
    this.onCancel,
  });
  final String title;
  final List<Widget> children;
  final bool dirty, busy;
  final VoidCallback? onCancel;
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  bool _allowPop = false, _confirming = false;
  Future<void> _leave() async {
    if (_confirming) return;
    _confirming = true;
    if ((widget.dirty || widget.busy) && !_allowPop) {
      final leave = await confirmDiscard(
        context,
        widget.busy
            ? 'A request is in progress. Leaving does not cancel a committed result.'
            : 'Discard the information entered in this form?',
      );
      if (!mounted) return;
      if (!leave) {
        _confirming = false;
        return;
      }
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
    _confirming = false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !widget.dirty && !widget.busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
  );
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
