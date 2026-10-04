import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../data/catalog_models.dart';
import '../data/home_models.dart';
import 'catalog_widgets.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller = HomeController(
    discovery: widget.dependencies.discovery!,
    session: widget.dependencies.session,
    guestStore: widget.dependencies.guestRecent!,
    recentlyViewed: widget.dependencies.recentlyViewed!,
    clock: widget.dependencies.clock,
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
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _controller.load(refresh: true),
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final home = _controller.home;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchBar(context),
                  if (!widget.dependencies.session.active)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Sign in'),
                      ),
                    ),
                  if (_controller.loading && home == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 56),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Loading Home',
                        ),
                      ),
                    )
                  else if (_controller.error != null && home == null)
                    _errorState(context, _controller.error!)
                  else if (home != null) ...[
                    if (_controller.error != null) _warning(_controller.error!),
                    if (_campaign(home) case final campaign?)
                      _campaignBanner(context, campaign),
                    if (home.categories.isNotEmpty)
                      _categories(context, home.categories),
                    if (_supportedActions(home).isNotEmpty)
                      _quickActions(context, _supportedActions(home)),
                    if (home.flashDeals case final deals?
                        when deals.products.isNotEmpty)
                      _productRail(context, deals.title, deals.products),
                    if (home.topProducts.isNotEmpty)
                      _productRail(
                        context,
                        'Popular right now',
                        home.topProducts,
                      ),
                    if (widget.dependencies.session.active &&
                        home.recentlyViewed.isNotEmpty)
                      _productRail(
                        context,
                        'Recently viewed',
                        home.recentlyViewed,
                      ),
                    if (!widget.dependencies.session.active &&
                        _controller.guestRecentlyViewed.isNotEmpty)
                      _productRail(
                        context,
                        'Recently viewed on this device',
                        _controller.guestRecentlyViewed,
                      ),
                    if (_controller.guestStorageUnavailable &&
                        _controller.guestRecentlyViewed.isNotEmpty)
                      const Text(
                        'Recent items are available for this visit, but could not be saved on this device.',
                      ),
                    if (_controller.recommendations.isNotEmpty)
                      _recommendations(context),
                    if (_controller.hasMore || _controller.loadingMore)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: FilledButton.tonal(
                            onPressed: _controller.loadingMore
                                ? null
                                : _controller.loadMore,
                            child: _controller.loadingMore
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Load more recommendations'),
                          ),
                        ),
                      ),
                    if (_controller.pageError != null)
                      _retryInline(
                        _controller.pageError!,
                        _controller.loadMore,
                      ),
                  ],
                  if (home == null &&
                      !_controller.loading &&
                      _controller.error == null)
                    const Center(child: Text('Home content is unavailable.')),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () => context.push('/policies/terms_of_service'),
                    child: const Text('Terms and Privacy'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _searchBar(BuildContext context) => Semantics(
    button: true,
    label: 'Search Products or Shops',
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9D1D8)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFFBFD),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Search Products and Shops')),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    ),
  );

  HomeCampaign? _campaign(BuyerHome home) {
    final candidates = [
      ...?home.advertisementLayer?.primary,
      ...home.campaigns.hero,
    ];
    for (final campaign in candidates) {
      if (campaign.isActive) return campaign;
    }
    return null;
  }

  List<QuickAction> _supportedActions(BuyerHome home) => home.quickActions
      .where((action) => const {'search', 'shops'}.contains(action.key))
      .toList();

  Widget _campaignBanner(BuildContext context, HomeCampaign campaign) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(top: 12, bottom: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      onTap: () => widget.dependencies.launcher.open(campaign.destinationUrl),
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (campaign.imageMobileUrl ?? campaign.imageDesktopUrl
                case final url?)
              Positioned.fill(
                child: CatalogImage(
                  url: url,
                  discovery: widget.dependencies.discovery!,
                  width: double.infinity,
                  height: 188,
                  label: campaign.altText,
                ),
              )
            else
              const ColoredBox(color: Color(0xFFF4EAF1)),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xCC251323),
                child: Text(
                  campaign.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                  semanticsLabel: campaign.altText,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _categories(
    BuildContext context,
    List<HomeCategory> categories,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(title: 'Explore categories'),
      const SizedBox(height: 8),
      SizedBox(
        height: 102 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return SizedBox(
              width: 96,
              child: TextButton(
                onPressed: () => context.push(
                  '/search?mode=products&q=${Uri.encodeQueryComponent(category.name)}',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE8E1E6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  category.name,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _quickActions(BuildContext context, List<QuickAction> actions) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final action in actions)
        OutlinedButton.icon(
          onPressed: () =>
              context.go(action.key == 'shops' ? '/shops' : '/search'),
          icon: Icon(
            action.key == 'shops' ? Icons.storefront_outlined : Icons.search,
          ),
          label: Text(action.label),
        ),
    ],
  );

  Widget _productRail(
    BuildContext context,
    String title,
    List<ProductCard> products,
  ) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: title,
          action: TextButton(
            onPressed: () => context.push('/search'),
            child: const Text('See more'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 310 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => ProductCardTile(
              product: products[index],
              discovery: widget.dependencies.discovery!,
              onTap: () => context.push('/products/${products[index].id}'),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _recommendations(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Picked for you'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 210).floor().clamp(1, 5);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _controller.recommendations.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent:
                    310 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 8,
              ),
              itemBuilder: (context, index) {
                final product = _controller.recommendations[index];
                return ProductCardTile(
                  width: double.infinity,
                  product: product,
                  discovery: widget.dependencies.discovery!,
                  onTap: () => context.push('/products/${product.id}'),
                );
              },
            );
          },
        ),
      ],
    ),
  );

  Widget _errorState(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42),
        const SizedBox(height: 12),
        const Text('Home content is unavailable.'),
        Text(message),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _controller.load(refresh: true),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _warning(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text('Some content could not be refreshed. $message'),
  );

  Widget _retryInline(String message, VoidCallback retry) => Row(
    children: [
      Expanded(child: Text('More items could not be loaded. $message')),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );
}
