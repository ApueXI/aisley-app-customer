import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/session_controller.dart';
import '../../../core/ui/form_page.dart';
import 'action_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, this.returnTo = '/'});
  final SessionController session;
  final String returnTo;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  final _emailFocus = FocusNode(), _passwordFocus = FocusNode();
  final _action = ActionViewModel();
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_action.enabled || widget.session.checking) return;
    if (!validateForm(_form.currentState!)) return;
    final success = await _action.submit(
      () => widget.session.signIn(_email.text, _password.text),
    );
    if (!mounted) return;
    _password.clear();
    if (success) {
      if (widget.session.active) {
        context.go(widget.returnTo);
      } else if (widget.session.phase == SessionPhase.consentRequired) {
        context.go('/consent?returnTo=${Uri.encodeComponent(widget.returnTo)}');
      } else {
        context.go('/session?returnTo=${Uri.encodeComponent(widget.returnTo)}');
      }
    } else {
      if (_form.currentState != null) validateForm(_form.currentState!);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_action, widget.session]),
    builder: (context, _) => FormPage(
      title: 'Sign in',
      canLeave: false,
      dirty: _email.text.isNotEmpty || _password.text.isNotEmpty,
      busy: _action.busy,
      children: [
        Text(
          'Welcome to AISLEY',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text('Sign in with your approved Buyer account.'),
        if (widget.session.notice != null) Text(widget.session.notice!),
        if (_action.failure != null) FailureNotice(_action.failure!),
        if (_action.failure?.uncertain == true)
          const Text(
            'The sign-in result is unconfirmed. A deliberate new attempt may create another session.',
          ),
        if (_action.failure == null && widget.session.failure != null)
          FailureNotice(widget.session.failure!),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  focusNode: _emailFocus,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      emailError(v) ?? _action.fieldError('email'),
                  onChanged: (_) {
                    _action.clearField('email');
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      requiredText(v, max: 10000) ??
                      _action.fieldError('password'),
                  onChanged: (_) {
                    _action.clearField('password');
                    setState(() {});
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        FilledButton(
          onPressed: _action.enabled && !widget.session.checking
              ? _submit
              : null,
          child: Text(_action.busy ? 'Signing in…' : 'Sign in'),
        ),
        TextButton(
          onPressed: _action.busy
              ? null
              : () => context.push('/forgot-password'),
          child: const Text('Forgot password?'),
        ),
        TextButton(
          onPressed: _action.busy ? null : () => context.push('/register'),
          child: const Text('Create a Buyer account'),
        ),
        TextButton(
          onPressed: () => context.push('/policies/terms_of_service'),
          child: const Text('Terms of Service'),
        ),
        TextButton(
          onPressed: () => context.push('/policies/privacy_policy'),
          child: const Text('Privacy Policy'),
        ),
      ],
    ),
  );
}
