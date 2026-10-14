import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_email_controller.dart';

class RegistrationEmailFields extends StatefulWidget {
  const RegistrationEmailFields({
    super.key,
    required this.controller,
    this.onVerified,
    this.disabled = false,
  });
  final RegistrationEmailController controller;
  final VoidCallback? onVerified;
  final bool disabled;
  @override
  State<RegistrationEmailFields> createState() =>
      _RegistrationEmailFieldsState();
}

class _RegistrationEmailFieldsState extends State<RegistrationEmailFields> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _email.text = widget.controller.email;
  }

  Future<void> _send() async {
    final c = widget.controller;
    if (widget.disabled || c.busy || c.resendSeconds > 0) return;
    if (c.challenge == null && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (await c.send(_email.text) && mounted) {
      _code.clear();
      _codeFocus.requestFocus();
    }
  }

  Future<void> _verify() async {
    if (widget.disabled || !(_form.currentState?.validate() ?? false)) return;
    if (await widget.controller.verify(_code.text) && mounted) {
      _code.clear();
      widget.onVerified?.call();
    } else if (mounted) {
      _codeFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.verified ? 'Your email is verified' : 'Verify your email',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              c.verified ? c.verifiedEmail : 'Confirm your email with a six-digit code before completing registration. Your application will still need approval.',
            ),
            if (c.message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  c.message!,
                  style: TextStyle(
                    color: c.failed
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (c.verified)
              TextButton(
                onPressed: widget.disabled ? null : c.reset,
                child: const Text('Change email'),
              )
            else ...[
              TextFormField(
                controller: _email,
                enabled: !c.busy && c.challenge == null && !widget.disabled,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                maxLength: 255,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Enter a valid email address.'
                    : null,
                onFieldSubmitted: (_) => _send(),
              ),
              if (c.challenge != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !c.busy && !widget.disabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                  validator: (v) =>
                      v == null || !RegExp(r'^[0-9]{6}$').hasMatch(v)
                      ? 'Enter all six digits.'
                      : null,
                  onFieldSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 8),
                Text(
                  c.expired ? 'This code expired. Request a new one.' : 'Use the latest code. It expires ten minutes after your request.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    c.busy || c.coolingDown || c.expired || widget.disabled
                    ? null
                    : c.challenge == null
                    ? _send
                    : _verify,
                child: Text(
                  c.busy
                      ? 'Please wait…'
                      : c.challenge == null
                      ? 'Send verification code'
                      : 'Verify email',
                ),
              ),
              if (c.challenge != null) ...[
                TextButton(
                  onPressed: c.busy || c.resendSeconds > 0 || widget.disabled
                      ? null
                      : _send,
                  child: Text(
                    c.resendSeconds > 0
                        ? 'Resend in ${c.resendSeconds}s'
                        : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: widget.disabled
                      ? null
                      : () {
                          _code.clear();
                          c.reset();
                        },
                  child: const Text('Change email'),
                ),
              ],
              if (c.coolingDown)
                Text('Please wait ${c.resendSeconds}s before trying again.'),
            ],
          ],
        ),
      );
    },
  );
}
