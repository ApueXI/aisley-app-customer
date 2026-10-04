import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/form_page.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'action_view_model.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.repository,
    required this.clock,
  });
  final AuthRepository repository;
  final DateTime Function() clock;
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'first_name',
      'middle_name',
      'last_name',
      'contact_number',
      'birth_date',
      'email',
      'password',
      'password_confirmation',
    ])
      key: TextEditingController(),
  };
  final _action = ActionViewModel();
  final _focus = {
    for (final key in [
      'first_name',
      'middle_name',
      'last_name',
      'contact_number',
      'sex',
      'birth_date',
      'email',
      'password',
      'password_confirmation',
    ])
      key: FocusNode(),
  };
  String? _sex;
  String _text(String key) => _fields[key]!.text;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _action.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  String? _birthday(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    final today = widget.clock();
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value ?? '') ||
        parsed.toIso8601String().substring(0, 10) != value ||
        !parsed.isBefore(DateTime(today.year, today.month, today.day))) {
      return 'Enter a date before today (YYYY-MM-DD).';
    }
    return _action.fieldError('birth_date');
  }

  Widget _field(
    String key,
    String label, {
    String? Function(String?)? validate,
    TextInputType? keyboard,
    bool secret = false,
    int max = 255,
  }) => TextFormField(
    controller: _fields[key],
    focusNode: _focus[key],
    obscureText: secret,
    enableSuggestions: !secret,
    autocorrect: !secret,
    keyboardType: keyboard,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(labelText: label),
    validator: (v) =>
        (validate ?? ((v) => requiredText(v, max: max)))(v) ??
        _action.fieldError(key),
    onChanged: (_) {
      _action.clearField(key);
      setState(() {});
    },
  );
  Future<void> _submit() async {
    if (!_action.enabled) return;
    if (!validateForm(_form.currentState!)) return;
    final input = RegistrationInput(
      firstName: _text('first_name'),
      middleName: _text('middle_name'),
      lastName: _text('last_name'),
      contactNumber: _text('contact_number'),
      sex: _sex!,
      birthDate: _text('birth_date'),
      email: _text('email'),
      password: _text('password'),
      confirmation: _text('password_confirmation'),
    );
    final success = await _action.submit(() async {
      await widget.repository.register(input);
    });
    if (!mounted) return;
    _fields['password']!.clear();
    _fields['password_confirmation']!.clear();
    if (success) {
      context.go('/approval');
    } else {
      validateForm(_form.currentState!);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _action,
    builder: (context, _) => FormPage(
      title: 'Create an account',
      busy: _action.busy,
      dirty: _fields.values.any((c) => c.text.isNotEmpty) || _sex != null,
      children: [
        const Text(
          'Registration requires Admin approval before you can sign in.',
        ),
        if (_action.failure != null) FailureNotice(_action.failure!),
        if (_action.failure?.uncertain == true)
          const Text(
            'The registration result is unconfirmed. Try signing in before deliberately submitting again; registration may already be pending.',
          ),
        Form(
          key: _form,
          child: Column(
            children: [
              _field('first_name', 'First name'),
              const SizedBox(height: 16),
              _field(
                'middle_name',
                'Middle name (optional)',
                validate: (v) => (v?.length ?? 0) > 255
                    ? 'Use at most 255 characters.'
                    : null,
              ),
              const SizedBox(height: 16),
              _field('last_name', 'Last name'),
              const SizedBox(height: 16),
              _field(
                'contact_number',
                'Contact number',
                keyboard: TextInputType.phone,
                max: 32,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _sex,
                focusNode: _focus['sex'],
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(
                    value: 'non_binary',
                    child: Text('Non-binary'),
                  ),
                  DropdownMenuItem(
                    value: 'prefer_not_to_say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: (v) {
                  _action.clearField('sex');
                  setState(() => _sex = v);
                },
                validator: (v) =>
                    v == null ? 'Select an option.' : _action.fieldError('sex'),
              ),
              const SizedBox(height: 16),
              _field(
                'birth_date',
                'Birth date (YYYY-MM-DD)',
                validate: _birthday,
                keyboard: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              _field(
                'email',
                'Email',
                validate: emailError,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _field(
                'password',
                'Password',
                validate: passwordError,
                secret: true,
              ),
              const SizedBox(height: 16),
              _field(
                'password_confirmation',
                'Confirm password',
                secret: true,
                validate: (v) => v != _text('password')
                    ? 'Passwords must match.'
                    : requiredText(v),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: _action.enabled ? _submit : null,
          child: Text(_action.busy ? 'Submitting…' : 'Register'),
        ),
        const Text(
          'Address and ID evidence cannot be submitted in this registration flow.',
        ),
        TextButton(
          onPressed: _action.busy ? null : () => context.go('/login'),
          child: const Text('Already registered? Sign in'),
        ),
      ],
    ),
  );
}
