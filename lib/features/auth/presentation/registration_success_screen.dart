import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/form_page.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({required this.active, super.key});
  final bool active;

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Account created successfully',
    onCancel: () => context.go('/login'),
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          active ? 'Your account is ready. You can now sign in.' : 'Your registration was submitted successfully. Please wait for Admin approval before signing in. We’ll email you once your application has been reviewed.',
        ),
      ),
      FilledButton(
        onPressed: () => context.go('/login'),
        child: const Text('Go to sign in'),
      ),
    ],
  );
}
