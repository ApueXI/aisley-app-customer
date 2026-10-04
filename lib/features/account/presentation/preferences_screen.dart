import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import 'account_controllers.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final PromotionPreferenceController _controller =
      PromotionPreferenceController(
        widget.dependencies.session,
        widget.dependencies.accounts!,
      );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => FormPage(
      title: 'Promotional messages',
      busy: _controller.saving,
      children: [
        const Text(
          'This optional setting is separate from Terms and Privacy consent.',
        ),
        if (_controller.loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading preference'),
        if (_controller.error != null)
          Semantics(liveRegion: true, child: Text(_controller.error!)),
        if (_controller.preference == null && !_controller.loading)
          OutlinedButton(
            onPressed: _controller.load,
            child: const Text('Refresh preference'),
          ),
        if (_controller.preference case final preference?)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow in-app promotions'),
            subtitle: Text(
              preference.optedIn
                  ? 'Promotional messages are enabled.'
                  : 'Promotional messages are off.',
            ),
            value: preference.optedIn,
            onChanged: _controller.saving || _controller.coolingDown
                ? null
                : _controller.set,
          ),
      ],
    ),
  );
}
