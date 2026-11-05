import 'dart:async';

import 'package:flutter/material.dart';

import 'appearance_controller.dart';
import 'appearance_scope.dart';

class AppearanceTile extends StatelessWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppearanceScope.maybeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Appearance'),
          subtitle: Text(
            controller == null ? 'System' : appearanceLabel(controller.mode),
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: controller != null,
          onTap: controller == null ? null : () => _choose(context, controller),
        ),
        if (controller?.saveFailed == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Appearance changed for now, but could not be remembered on this device.',
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(controller!.retry()),
                  child: const Text('Retry saving'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    AppearanceController controller,
  ) async {
    final choice = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: controller.mode,
            onChanged: (mode) {
              if (mode != null) Navigator.of(context).pop(mode);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(appearanceLabel(mode)),
                    subtitle: mode == ThemeMode.system
                        ? const Text('Use device setting')
                        : null,
                  ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ),
        ],
      ),
    );
    if (choice != null) unawaited(controller.select(choice));
  }
}
