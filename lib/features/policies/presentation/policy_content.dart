import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../data/policy_models.dart';

class PolicyContent extends StatelessWidget {
  const PolicyContent({
    super.key,
    required this.policy,
    required this.launcher,
  });
  final PublicPolicy policy;
  final TrustedLauncher launcher;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        policy.version.title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text('Version ${policy.version.version}'),
      if (policy.version.changeSummary != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(policy.version.changeSummary!),
        ),
      const SizedBox(height: 16),
      MarkdownBody(
        data: policy.version.content,
        selectable: true,
        imageBuilder: (_, _, _) => const Text('External image omitted.'),
        onTapLink: (_, href, _) async {
          if (href == null) return;
          final trusted = launcher.config.trustedLink(href);
          if (trusted == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This link is outside the trusted storefront.'),
              ),
            );
            return;
          }
          final approved = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Open storefront link?'),
              content: Text(trusted.host),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open'),
                ),
              ],
            ),
          );
          if (approved == true) {
            final opened = await launcher.open(href);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('The link could not be opened.')),
              );
            }
          }
        },
      ),
    ],
  );
}
