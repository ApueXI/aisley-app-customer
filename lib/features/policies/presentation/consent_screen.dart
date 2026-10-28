import 'package:flutter/material.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../../../core/security/session_controller.dart';
import '../../../core/ui/form_page.dart';
import '../data/policy_repository.dart';
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
      title: 'Required consent',
      showAppBar: false,
      canLeave: false,
      busy: _model.busy,
      children: [
        Text(
          'Required consent',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'Read each required current policy and explicitly confirm acceptance to continue.',
        ),
        if (_model.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading required policy',
          ),
        if (_model.failure != null) FailureNotice(_model.failure!),
        if (_model.policy != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PolicyContent(
                policy: _model.policy!,
                launcher: widget.launcher,
              ),
            ),
          ),
          CheckboxListTile(
            value: _model.confirmed,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(
              'I have read and accept ${_model.policy!.label}, version ${_model.policy!.version.version}.',
            ),
            onChanged: _model.busy
                ? null
                : (value) => _model.confirm(value ?? false),
          ),
        ],
        if (_model.failure != null || _model.policy == null && !_model.loading)
          OutlinedButton(
            onPressed: _model.busy ? null : _model.load,
            child: const Text('Refresh policies'),
          ),
        if (_model.policy != null)
          FilledButton(
            onPressed: _model.mayAccept ? _model.accept : null,
            child: Text(_model.busy ? 'Accepting…' : 'Accept and continue'),
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
