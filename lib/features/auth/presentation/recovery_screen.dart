import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../../../core/ui/form_page.dart';
import '../data/auth_repository.dart';
import 'action_view_model.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.repository,
    required this.launcher,
  });
  final AuthRepository repository;
  final TrustedLauncher launcher;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _emailFocus = FocusNode();
  final _action = ActionViewModel();
  String? _linkError;
  @override
  void dispose() {
    _email.dispose();
    _emailFocus.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _action,
    builder: (context, _) => FormPage(
      title: 'Recover your password',
      dirty: _email.text.isNotEmpty && !_action.succeeded,
      busy: _action.busy,
      onCancel: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      children: [
        const Text('Enter your email to request password recovery.'),
        if (_action.failure != null) FailureNotice(_action.failure!),
        if (_action.succeeded)
          Semantics(
            liveRegion: true,
            child: const Text(
              'If your account is eligible, recovery instructions will be sent. Follow the email link in the trusted storefront.',
            ),
          ),
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            focusNode: _emailFocus,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => emailError(v) ?? _action.fieldError('email'),
            onChanged: (_) {
              _action.clearField('email');
              setState(() {});
            },
          ),
        ),
        FilledButton(
          onPressed: _action.enabled
              ? () async {
                  if (validateForm(_form.currentState!)) {
                    await _action.submit(
                      () => widget.repository.forgotPassword(_email.text),
                    );
                    if (mounted && _form.currentState != null) {
                      validateForm(_form.currentState!);
                    }
                  }
                }
              : null,
          child: Text(_action.busy ? 'Requesting…' : 'Request recovery'),
        ),
        OutlinedButton(
          onPressed: () async {
            final opened = await widget.launcher.open('/reset-password');
            if (mounted) {
              setState(
                () => _linkError = opened ? null : 'The storefront could not be opened. Use the link in your recovery email.',
              );
            }
          },
          child: const Text('Open trusted storefront'),
        ),
        if (_linkError != null) Text(_linkError!),
      ],
    ),
  );
}
