import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../../../core/ui/form_page.dart';
import '../data/policy_models.dart';
import '../data/policy_repository.dart';
import 'policy_content.dart';
import 'policy_view_models.dart';

class PolicyReaderScreen extends StatefulWidget {
  const PolicyReaderScreen({
    super.key,
    required this.repository,
    required this.launcher,
    required this.type,
    this.version,
  });
  final PolicyRepository repository;
  final TrustedLauncher launcher;
  final PolicyType type;
  final int? version;
  @override
  State<PolicyReaderScreen> createState() => _PolicyReaderScreenState();
}

class _PolicyReaderScreenState extends State<PolicyReaderScreen> {
  late final _model = PolicyReaderViewModel(
    widget.repository,
    widget.type,
    widget.version,
  );
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
    listenable: _model,
    builder: (context, _) => FormPage(
      title: widget.type.label,
      onCancel: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      children: [
        if (_model.loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading policy'),
        if (_model.failure != null) ...[
          FailureNotice(_model.failure!),
          OutlinedButton(onPressed: _model.load, child: const Text('Retry')),
        ],
        if (_model.policy != null)
          PolicyContent(policy: _model.policy!, launcher: widget.launcher),
        OutlinedButton(
          onPressed: _model.historyLoading ? null : _model.loadHistory,
          child: Text(
            _model.historyLoading ? 'Loading history…' : 'View policy history',
          ),
        ),
        if (_model.historyFailure != null)
          FailureNotice(_model.historyFailure!),
        if (_model.history?.versions.isEmpty == true)
          const Text('No published history is available.'),
        if (_model.history != null)
          ..._model.history!.versions.map(
            (version) => ListTile(
              title: Text(version.title),
              subtitle: Text('Version ${version.version}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/policies/${widget.type.wire}/history/${version.version}',
              ),
            ),
          ),
      ],
    ),
  );
}
