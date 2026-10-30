import '../data/registration_email.dart';
import 'registration_email_controller.dart';
import 'registration_email_fields.dart';

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
  late final RegistrationEmailController _verification;

  @override
  void initState() {
    super.initState();
    _verification = RegistrationEmailController(
      widget.repository as RegistrationEmailRepository,
      clock: widget.clock,
    );
  }

  bool _showVerification = false;
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
    _verification.dispose();
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
      return 'Choose a date before today.';
    }
    return _action.fieldError('birth_date');
  }

  Future<void> _pickBirthDate() async {
    if (_action.busy) return;
    final today = DateUtils.dateOnly(widget.clock());
    final firstDate = DateTime(1900);
    final lastDate = DateTime(today.year, today.month, today.day - 1);
    final current = DateTime.tryParse(_text('birth_date')) ?? DateTime(2000);
    final initialDate = current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
        ? lastDate
        : current;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Choose your birth date',
    );
    if (!mounted || date == null || _action.busy) return;
    _action.clearField('birth_date');
    setState(() {
      _fields['birth_date']!.text =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    });
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
    enabled: !_action.busy,
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
      if (key == 'email' &&
          _text('email').trim().toLowerCase() != _verification.email) {
        _verification.reset();
        _showVerification = false;
      }
      _action.clearField(key);
      setState(() {});
    },
  );
  Future<void> _submit() async {
    if (!_action.enabled || !_verification.verified) return;
    if (!validateForm(_form.currentState!)) return;
    final input = RegistrationInput(
      firstName: _text('first_name'),
      middleName: _text('middle_name'),
      lastName: _text('last_name'),
      contactNumber: _text('contact_number'),
      sex: _sex!,
      birthDate: _text('birth_date'),
      email: _verification.verifiedEmail,
      emailVerificationToken: _verification.proof!.token,
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
      if (_action.failure?.fields.containsKey('email_verification_token') ==
          true) {
        _verification.reset();
      }
      validateForm(_form.currentState!);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_action, _verification]),
    builder: (context, _) => FormPage(
      title: 'Create an account',
      busy: _action.busy,
      dirty: _fields.values.any((c) => c.text.isNotEmpty) || _sex != null,
      onCancel: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      children: [
        const Text(
          'Registration requires Admin approval before you can sign in.',
        ),
        if (_action.failure != null) FailureNotice(_action.failure!),
        if (_action.failure?.uncertain == true)
          const Text(
            'The registration result is unconfirmed. Try signing in before deliberately submitting again; registration may already be pending.',
          ),
        Offstage(
          offstage: false,
          child: Form(
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
                  itemHeight: null,
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
                  onChanged: _action.busy
                      ? null
                      : (v) {
                          _action.clearField('sex');
                          setState(() => _sex = v);
                        },
                  validator: (v) => v == null
                      ? 'Select an option.'
                      : _action.fieldError('sex'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fields['birth_date'],
                  focusNode: _focus['birth_date'],
                  enabled: !_action.busy,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  decoration: InputDecoration(
                    labelText: 'Birth date',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      tooltip: 'Choose birth date',
                      onPressed: _action.busy ? null : _pickBirthDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  validator: _birthday,
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
        ),
        if (!_verification.verified && !_showVerification)
          FilledButton(
            onPressed: _action.enabled
                ? () {
                    if (!validateForm(_form.currentState!)) return;
                    setState(() => _showVerification = true);
                  }
                : null,
            child: const Text('Continue to email verification'),
          ),
        if (_showVerification)
          RegistrationEmailFields(
            controller: _verification,
            draftEmail: _text('email'),
            disabled: _action.busy,
          ),
        if (_verification.verified)
          FilledButton(
            onPressed: _action.enabled ? _submit : null,
            child: Text(_action.busy ? 'Submitting…' : 'Submit registration'),
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
