import 'package:flutter/material.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../../../core/security/session_controller.dart';
import '../../../core/ui/form_page.dart';
import '../data/policy_repository.dart';
import '../data/policy_models.dart';

import 'package:go_router/go_router.dart';

import 'policy_content.dart';
import 'policy_view_models.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.launcher,
    required this.returnTo,
  });
  final PolicyRepository repository;
  final SessionController session;
  final TrustedLauncher launcher;
  final String returnTo;
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  late final _model = ConsentViewModel(widget.repository, widget.session);
  @override
  void initState() {
    super.initState();
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_model, widget.session]),
    builder: (context, _) => FormPage(
      title: 'Terms and Privacy',
      showAppBar: false,
      canLeave: false,
      busy: _model.busy,
      children: [
        Text(
          'Terms and Privacy',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'Review the Terms of Service and Privacy Policy, then confirm below.',
        ),
        if (_model.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading required policy',
          ),
        if (_model.failure != null) FailureNotice(_model.failure!),
        if (_model.documents.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final type in PolicyType.values) ...[
                    if (_model.documents[type] != null)
                      PolicyContent(
                        usePolicyLabel: true,
                        policy: _model.documents[type]!,
                        launcher: widget.launcher,
                      )
                    else
                      Text('${type.label}: no published version is available.'),
                    TextButton(
                      onPressed: () => context.push('/policies/${type.wire}'),
                      child: Text('View ${type.label} history'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Your confirmation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final type in PolicyType.values)
                    CheckboxListTile(
                      value: _model.confirmed(type),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 56,
                      title: Text(
                        _model.covered(type)
                            ? '${type.label}: no further confirmation needed.'
                            : 'I have read and agree to the ${type.label}${_model.documents[type] == null ? '' : ', version ${_model.documents[type]!.version.version}'}.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      onChanged:
                          _model.busy ||
                              _model.loading ||
                              !_model.enabled ||
                              _model.statusFor(type)?.required != true ||
                              _model.documents[type] == null
                          ? null
                          : (value) => _model.confirm(type, value ?? false),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _model.mayAccept ? _model.accept : null,
                    child: Text(_model.busy ? 'Accepting…' : 'Accept'),
                  ),
                  if (widget.session.active)
                    const Text('Your policy consent is up to date.'),
                ],
              ),
            ),
          ),
        if (_model.failure != null ||
            _model.documents.isEmpty && !_model.loading)
          OutlinedButton(
            onPressed: !_model.enabled || _model.loading ? null : _model.load,
            child: const Text('Refresh policies'),
          ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: widget.session.signingOut
                ? null
                : widget.session.signOut,
            child: const Text('Sign out'),
          ),
        ),
      ],
    ),
  );
}
