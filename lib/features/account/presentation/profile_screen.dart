import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../data/account_models.dart';
import 'account_controllers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller = ProfileController(
    widget.dependencies.session,
    widget.dependencies.accounts!,
  );
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(), _middle = TextEditingController();
  final _last = TextEditingController(), _contact = TextEditingController();
  String? _sex, _birthDate;
  String _initial = '';
  bool _hydrated = false, _hydrating = false;

  static const _sexValues = {
    'male': 'Male',
    'female': 'Female',
    'non_binary': 'Non-binary',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.registerPrivateCleanup(_clearDraft);
    for (final field in [_first, _middle, _last, _contact]) {
      field.addListener(_changed);
    }
    _controller.load();
  }

  @override
  void dispose() {
    widget.dependencies.session.unregisterPrivateCleanup(_clearDraft);
    for (final field in [_first, _middle, _last, _contact]) {
      field.removeListener(_changed);
    }
    _controller.dispose();
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final account = _controller.account;
      if (account != null && !_hydrated) _hydrate(account);
      return FormPage(
        title: 'Profile',
        dirty: _hydrated && _snapshot() != _initial,
        busy: _controller.saving,
        children: [
          if (!_hydrated && _controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading profile'),
          if (_controller.error != null)
            _Message(_controller.error!, onRetry: _reviewSavedProfile),
          if (account == null && !_controller.loading) ...[
            const Text('Your profile could not be loaded.'),
            OutlinedButton(
              onPressed: _controller.load,
              child: const Text('Retry'),
            ),
          ],
          if (account != null) ...[
            Text('Email', style: Theme.of(context).textTheme.labelLarge),
            SelectableText(account.email),
            const Text('Email, role and account status are managed by AISLEY.'),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _first,
                    decoration: const InputDecoration(labelText: 'First name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        requiredText(value) ??
                        _controller.fieldErrors['first_name'],
                  ),
                  TextFormField(
                    controller: _middle,
                    decoration: const InputDecoration(
                      labelText: 'Middle name (optional)',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value?.length ?? 0) > 255
                        ? 'Use at most 255 characters.'
                        : _controller.fieldErrors['middle_name'],
                  ),
                  TextFormField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        requiredText(value) ??
                        _controller.fieldErrors['last_name'],
                  ),
                  TextFormField(
                    controller: _contact,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        requiredText(value, max: 32) ??
                        _controller.fieldErrors['contact_number'],
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: [
                      for (final entry in _sexValues.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    validator: (value) => value == null
                        ? 'Choose an option.'
                        : _controller.fieldErrors['sex'],
                    onChanged: (value) => setState(() => _sex = value),
                  ),
                  TextFormField(
                    key: ValueKey(_birthDate),
                    initialValue: _birthDate ?? '',
                    readOnly: true,
                    onTap: _pickBirthDate,
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: IconButton(
                        tooltip: 'Choose birthday',
                        onPressed: _pickBirthDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                    validator: (value) => _birthDate == null
                        ? 'Choose your birthday.'
                        : _controller.fieldErrors['birth_date'],
                  ),
                ],
              ),
            ),
            if (account.profile.age != null)
              Text(
                'Age is calculated from your birthday: ${account.profile.age}.',
              ),
            FilledButton.icon(
              onPressed:
                  _controller.saving ||
                      _controller.coolingDown ||
                      _controller.requiresReconciliation
                  ? null
                  : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_controller.saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        ],
      );
    },
  );

  void _hydrate(CustomerAccount account) {
    _hydrating = true;
    _hydrated = true;
    _first.text = account.profile.firstName ?? '';
    _middle.text = account.profile.middleName ?? '';
    _last.text = account.profile.lastName ?? '';
    _contact.text = account.profile.contactNumber ?? '';
    _sex = _sexValues.containsKey(account.profile.sex)
        ? account.profile.sex
        : null;
    _birthDate = account.profile.birthDate;
    _initial = _snapshot();
    _hydrating = false;
  }

  void _changed() {
    if (_hydrating) return;
    _controller.fieldErrors = const {};
    if (mounted) setState(() {});
  }

  void _clearDraft() {
    for (final field in [_first, _middle, _last, _contact]) {
      field.clear();
    }
    _sex = null;
    _birthDate = null;
    _initial = '';
    _hydrated = false;
  }

  Future<void> _reviewSavedProfile() async {
    if (_snapshot() != _initial &&
        !await confirmDiscard(
          context,
          'Discard this draft and review the saved profile?',
        )) {
      return;
    }
    await _controller.load();
    if (mounted && _controller.account != null) {
      setState(() => _hydrate(_controller.account!));
    }
  }

  String _snapshot() => [
    _first.text.trim(),
    _middle.text.trim(),
    _last.text.trim(),
    _contact.text.trim(),
    _sex ?? '',
    _birthDate ?? '',
  ].join('\u001f');

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(widget.dependencies.clock());
    final initial = DateTime.tryParse(_birthDate ?? '') ?? DateTime(2000);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today)
          ? initial
          : today.subtract(const Duration(days: 1)),
      firstDate: DateTime(1900),
      lastDate: today.subtract(const Duration(days: 1)),
      helpText: 'Choose your birthday',
    );
    if (date != null && mounted) {
      setState(
        () => _birthDate =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _save() async {
    if (!validateForm(_form.currentState!)) return;
    final ok = await _controller.save(
      ProfileInput(
        firstName: _first.text,
        middleName: _middle.text,
        lastName: _last.text,
        contactNumber: _contact.text,
        sex: _sex!,
        birthDate: _birthDate!,
      ),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _initial = _snapshot());
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
      context.pop();
    } else {
      validateForm(_form.currentState!);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text(message)),
      if (onRetry != null)
        TextButton(onPressed: onRetry, child: const Text('Refresh')),
    ],
  );
}
