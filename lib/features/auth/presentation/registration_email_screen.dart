import 'dart:async';

import 'package:flutter/material.dart';

import 'registration_email_controller.dart';
import 'registration_email_fields.dart';

class RegistrationEmailScreen extends StatefulWidget {
  const RegistrationEmailScreen({
    required this.controller,
    required this.email,
    super.key,
  });
  final RegistrationEmailController controller;
  final String email;
  @override
  State<RegistrationEmailScreen> createState() =>
      _RegistrationEmailScreenState();
}

class _RegistrationEmailScreenState extends State<RegistrationEmailScreen> {
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.challenge == null) {
        unawaited(widget.controller.send(widget.email));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify your email')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Verifying your email will automatically submit your registration.',
                ),
                const SizedBox(height: 24),
                RegistrationEmailFields(
                  controller: widget.controller,
                  draftEmail: widget.email,
                  onVerified: () {
                    if (_finished || !mounted) return;
                    _finished = true;
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Back to edit details'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
