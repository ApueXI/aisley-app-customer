import 'package:flutter/material.dart';

import 'marketplace_chrome.dart';
export 'marketplace_chrome.dart';

double pageSpacing(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600
    ? 16
    : MediaQuery.sizeOf(context).width < 1024
    ? 24
    : 32;

EdgeInsets pagePadding(BuildContext context) =>
    EdgeInsets.all(pageSpacing(context));

double catalogTextScale(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2);

/// Constrains the viewport, leaving scrolling and input state with the child.
class ContentViewport extends StatelessWidget {
  const ContentViewport({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.shrinkWrap = false,
  });
  final Widget child;
  final double maxWidth;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: shrinkWrap ? 1 : null,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Shopping routes outside the bottom-navigation shell own one scaffold.
class ShoppingPage extends StatelessWidget {
  const ShoppingPage({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: marketplaceAppBar(context, appBar),
    body: SafeArea(child: ContentViewport(child: body)),
    bottomNavigationBar: bottomBar == null
        ? null
        : SafeArea(
            top: false,
            child: ContentViewport(shrinkWrap: true, child: bottomBar!),
          ),
  );
}

/// Natural card heights prevent prices, ratings and actions being clipped.
class CatalogGrid extends StatelessWidget {
  const CatalogGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final minimum = 160 * catalogTextScale(context);
      final columns = ((constraints.maxWidth + gap) / (minimum + gap))
          .floor()
          .clamp(1, 6);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
