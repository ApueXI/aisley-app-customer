import 'package:flutter/material.dart';

import 'appearance_controller.dart';

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

/// Owns the device preference above all routes and session transitions.
class AppearanceRoot extends StatefulWidget {
  const AppearanceRoot({
    super.key,
    required this.controller,
    required this.child,
  });
  final AppearanceController controller;
  final Widget child;

  @override
  State<AppearanceRoot> createState() => _AppearanceRootState();
}

class _AppearanceRootState extends State<AppearanceRoot> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppearanceScope(controller: widget.controller, child: widget.child);
}
