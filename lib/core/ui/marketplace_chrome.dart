import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'message_action.dart';

/// Navigation receives display values only; session authority stays in the app.
class MarketplaceScope extends InheritedWidget {
  const MarketplaceScope({
    super.key,
    required this.active,
    required this.cartCount,
    this.chatUnread,
    this.chatStale = false,
    this.chatUpdatesManaged = false,
    required super.child,
  });
  final bool active;
  final int? cartCount;
  final int? chatUnread;
  final bool chatStale, chatUpdatesManaged;
  static MarketplaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarketplaceScope>();
  @override
  bool updateShouldNotify(MarketplaceScope oldWidget) =>
      active != oldWidget.active ||
      cartCount != oldWidget.cartCount ||
      chatUnread != oldWidget.chatUnread ||
      chatStale != oldWidget.chatStale ||
      chatUpdatesManaged != oldWidget.chatUpdatesManaged;
}

List<Widget> marketplaceActions(BuildContext context) {
  final scope = MarketplaceScope.maybeOf(context);
  return [
    MessageAction(
      unread: scope?.chatUnread,
      stale: scope?.chatStale ?? false,
      onPressed: () => context.push('/messages'),
    ),
    IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: const Icon(Icons.notifications_outlined),
    ),
    IconButton(
      tooltip: 'Terms and privacy',
      onPressed: () => context.push('/policies/terms_of_service'),
      icon: const Icon(Icons.policy_outlined),
    ),
  ];
}

bool marketplaceDesktop(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final scaler = MediaQuery.textScalerOf(context);
  if (width < 1024 || scaler.scale(16) > 24) return false;
  final style = Theme.of(context).textTheme.labelLarge;
  var utilityWidth = 0.0;
  for (final label in const [
    'AISLEY',
    'Shops',
    'Orders',
    'Cart (999)',
    'Account',
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
  return utilityWidth + 280 <= width.clamp(0, 1200) - 64;
}

class MarketplaceHeader extends StatefulWidget implements PreferredSizeWidget {
  const MarketplaceHeader({
    super.key,
    required this.desktop,
    required this.searchHeight,
    this.toolbar,
    this.cartCount,
    this.showSearch = false,
  });
  final bool desktop;
  final bool showSearch;
  final double searchHeight;
  final PreferredSizeWidget? toolbar;
  final int? cartCount;
  @override
  Size get preferredSize => Size.fromHeight(
    (desktop
            ? 48 + searchHeight
            : showSearch
            ? searchHeight
            : 0) +
        (toolbar?.preferredSize.height ?? 0),
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
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton.filled(
        tooltip: 'Search',
        onPressed: () => _submit(_search.text),
        icon: const Icon(Icons.search, color: Colors.white),
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
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
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
                    children: marketplaceActions(context),
                  ),
                ),
              ),
            if (widget.desktop || widget.showSearch)
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
                            if (widget.showSearch)
                              Expanded(child: _field())
                            else
                              const Spacer(),
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
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _field(),
                        ),
                ),
              ),
            if (widget.desktop && widget.toolbar != null) widget.toolbar!,
          ],
        ),
      ),
    ),
  );
}

PreferredSizeWidget? marketplaceAppBar(
  BuildContext context,
  PreferredSizeWidget? toolbar, {
  bool compact = false,
  bool showSearch = false,
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
          showSearch: showSearch,
        )
      : toolbar;
}
