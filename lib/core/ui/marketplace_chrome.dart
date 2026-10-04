import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation receives display values only; session authority stays in the app.
class MarketplaceScope extends InheritedWidget {
  const MarketplaceScope({
    super.key,
    required this.active,
    required this.cartCount,
    required super.child,
  });
  final bool active;
  final int? cartCount;
  static MarketplaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarketplaceScope>();
  @override
  bool updateShouldNotify(MarketplaceScope oldWidget) =>
      active != oldWidget.active || cartCount != oldWidget.cartCount;
}

bool marketplaceDesktop(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final scaler = MediaQuery.textScalerOf(context);
  if (width < 1024 || scaler.scale(16) > 24) return false;
  final style = Theme.of(context).textTheme.labelLarge;
  var utilityWidth = 0.0;
  for (final label in const [
    'Notifications',
    'Shop messages',
    'Logistics messages',
    'Courier messages',
  ]) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout();
    // Material TextButtons reserve 12px on each side, with a 48px target.
    utilityWidth += (painter.width + 24).clamp(48, double.infinity);
    painter.dispose();
  }
  return utilityWidth <= width.clamp(0, 1200) - 64;
}

class MarketplaceHeader extends StatefulWidget implements PreferredSizeWidget {
  const MarketplaceHeader({
    super.key,
    required this.desktop,
    required this.searchHeight,
    this.toolbar,
    this.cartCount,
  });
  final bool desktop;
  final double searchHeight;
  final PreferredSizeWidget? toolbar;
  final int? cartCount;
  @override
  Size get preferredSize => Size.fromHeight(
    (desktop ? 48 : 0) + searchHeight + (toolbar?.preferredSize.height ?? 0),
  );
  @override
  State<MarketplaceHeader> createState() => _MarketplaceHeaderState();
}

class _MarketplaceHeaderState extends State<MarketplaceHeader> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final q = query.trim();
    context.push(
      Uri(
        path: '/search',
        queryParameters: {'mode': 'products', if (q.isNotEmpty) 'q': q},
      ).toString(),
    );
  }

  Widget _field() => TextField(
    key: _fieldKey,
    controller: _search,
    focusNode: _focus,
    maxLength: 100,
    textInputAction: TextInputAction.search,
    onSubmitted: _submit,
    decoration: InputDecoration(
      counterText: '',
      hintText: 'Search Products and Shops',
      labelText: 'Search Products or Shops',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Search',
        onPressed: () => _submit(_search.text),
        icon: const Icon(Icons.arrow_forward),
      ),
    ),
  );
  Widget _bounds(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.desktop
              ? 32
              : MediaQuery.sizeOf(context).width >= 600
              ? 24
              : 16,
        ),
        child: child,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!widget.desktop && widget.toolbar != null) widget.toolbar!,
          if (widget.desktop)
            _bounds(
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final entry in const {
                      '/notifications': 'Notifications',
                      '/messages/shops': 'Shop messages',
                      '/messages/logistics': 'Logistics messages',
                      '/messages/courier': 'Courier messages',
                    }.entries)
                      TextButton(
                        onPressed: () => context.push(entry.key),
                        child: Text(entry.value),
                      ),
                  ],
                ),
              ),
            ),
          _bounds(
            SizedBox(
              height: widget.searchHeight,
              child: widget.desktop
                  ? Row(
                      children: [
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: Text(
                            'AISLEY',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _field()),
                        const SizedBox(width: 16),
                        for (final entry in const {
                          '/shops': 'Shops',
                          '/orders': 'Orders',
                          '/cart': 'Cart',
                          '/account': 'Account',
                        }.entries)
                          TextButton(
                            onPressed: () => entry.key == '/orders'
                                ? context.push(entry.key)
                                : context.go(entry.key),
                            child: Text(
                              entry.key == '/cart' &&
                                      (widget.cartCount ?? 0) > 0
                                  ? 'Cart (${widget.cartCount})'
                                  : entry.value,
                            ),
                          ),
                      ],
                    )
                  : _field(),
            ),
          ),
          if (widget.desktop && widget.toolbar != null) widget.toolbar!,
        ],
      ),
    ),
  );
}

PreferredSizeWidget? marketplaceAppBar(
  BuildContext context,
  PreferredSizeWidget? toolbar, {
  bool compact = false,
}) {
  final scope = MarketplaceScope.maybeOf(context);
  return !compact && scope?.active == true
      ? MarketplaceHeader(
          desktop: marketplaceDesktop(context),
          searchHeight: MediaQuery.textScalerOf(context).scale(16) > 24
              ? 88
              : 72,
          toolbar: toolbar,
          cartCount: scope?.cartCount,
        )
      : toolbar;
}
