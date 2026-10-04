import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      title: 'Review required policies',
      busy: _model.busy,
      children: [
        const Text(
          'Read each required current policy and explicitly confirm acceptance to continue.',
        ),
        if (_model.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading required policy',
          ),
        if (_model.failure != null) FailureNotice(_model.failure!),
        if (_model.policy != null) ...[
          PolicyContent(policy: _model.policy!, launcher: widget.launcher),
          CheckboxListTile(
            value: _model.confirmed,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I have read and accept ${_model.policy!.label}, version ${_model.policy!.version.version}.',
            ),
            onChanged: _model.busy
                ? null
                : (value) => _model.confirm(value ?? false),
          ),
          FilledButton(
            onPressed: _model.mayAccept ? _model.accept : null,
            child: Text(_model.busy ? 'Accepting…' : 'Accept this version'),
          ),
        ],
        if (_model.failure != null || _model.policy == null && !_model.loading)
          OutlinedButton(
            onPressed: _model.busy ? null : _model.load,
            child: const Text('Refresh policies'),
          ),
        if (widget.session.active)
          FilledButton(
            onPressed: () => context.go(widget.returnTo),
            child: const Text('Continue'),
          ),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Return to public Home'),
        ),
        TextButton(
          onPressed: widget.session.signingOut ? null : widget.session.signOut,
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
}
