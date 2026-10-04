import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import 'account_controllers.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  late final PasswordController _controller = PasswordController(
    widget.dependencies.session,
    widget.dependencies.accounts!,
  );
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(), _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true, _hideNext = true;

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.registerPrivateCleanup(_clearDraft);
    for (final field in [_current, _next, _confirm]) {
      field.addListener(_changed);
    }
  }

  void _changed() {
    _controller.fieldErrors = const {};
    if (mounted) setState(() {});
  }

  void _clearDraft() {
    _current.clear();
    _next.clear();
    _confirm.clear();
  }

  @override
  void dispose() {
    widget.dependencies.session.unregisterPrivateCleanup(_clearDraft);
    for (final field in [_current, _next, _confirm]) {
      field.removeListener(_changed);
    }
    _controller.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => FormPage(
      title: 'Change password',
      dirty:
          _current.text.isNotEmpty ||
          _next.text.isNotEmpty ||
          _confirm.text.isNotEmpty,
      busy: _controller.saving,
      children: [
        const Text(
          'Changing your password preserves this session and revokes other sessions.',
        ),
        if (_controller.error != null)
          Semantics(liveRegion: true, child: Text(_controller.error!)),
        if (_controller.changed)
          Semantics(
            liveRegion: true,
            child: const Text('Your password was changed.'),
          ),
        if (_controller.requiresReconciliation)
          OutlinedButton(
            onPressed: () async {
              if (await confirmAction(
                context,
                title: 'Verify changed password?',
                message: 'Sign out, then sign in with the password you believe is current before another change.',
                action: 'Sign out',
              )) {
                await widget.dependencies.session.signOut();
              }
            },
            child: const Text('Sign out to verify password'),
          ),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _current,
                obscureText: _hideCurrent,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    tooltip: _hideCurrent ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                    icon: Icon(
                      _hideCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) =>
                    requiredText(value, max: 10000) ??
                    _controller.fieldErrors['current_password'],
              ),
              TextFormField(
                controller: _next,
                obscureText: _hideNext,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters, mixed case and a number.',
                  suffixIcon: IconButton(
                    tooltip: _hideNext ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hideNext = !_hideNext),
                    icon: Icon(
                      _hideNext ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) =>
                    passwordError(value) ?? _controller.fieldErrors['password'],
              ),
              TextFormField(
                controller: _confirm,
                obscureText: _hideNext,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) => value != _next.text
                    ? 'The passwords do not match.'
                    : _controller.fieldErrors['password_confirmation'],
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed:
              _controller.saving ||
                  _controller.coolingDown ||
                  _controller.requiresReconciliation
              ? null
              : _submit,
          child: Text(_controller.saving ? 'Changing…' : 'Change password'),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!validateForm(_form.currentState!)) return;
    final success = await _controller.change(
      currentPassword: _current.text,
      password: _next.text,
      confirmation: _confirm.text,
    );
    if (!mounted) return;
    if (success) {
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() {});
    } else {
      validateForm(_form.currentState!);
    }
  }
}
