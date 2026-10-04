import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
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
    recentlyViewed: widget.dependencies.recentlyViewed!,
  );

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
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
          padding: pagePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (MarketplaceScope.maybeOf(context)?.active != true)
                    _searchBar(context),
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

  Widget _searchBar(BuildContext context) => TextField(
    controller: _search,
    maxLength: 100,
    textInputAction: TextInputAction.search,
    onSubmitted: _submitSearch,
    decoration: InputDecoration(
      counterText: '',
      labelText: 'Search Products or Shops',
      hintText: 'Search Products and Shops',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.arrow_forward),
        onPressed: () => _submitSearch(_search.text),
      ),
    ),
  );

  void _submitSearch(String value) => context.push(
    Uri(
      path: '/search',
      queryParameters: {
        'mode': 'products',
        if (value.trim().isNotEmpty) 'q': value.trim(),
      },
    ).toString(),
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
    child: InkWell(
      onTap: () => widget.dependencies.launcher.open(campaign.destinationUrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((MediaQuery.sizeOf(context).width >= 600
                  ? campaign.imageDesktopUrl ?? campaign.imageMobileUrl
                  : campaign.imageMobileUrl ?? campaign.imageDesktopUrl)
              case final url?)
            AspectRatio(
              aspectRatio: 2.4,
              child: CatalogImage(
                url: url,
                discovery: widget.dependencies.discovery!,
                label: campaign.altText,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              campaign.title,
              style: Theme.of(context).textTheme.titleLarge,
              semanticsLabel: campaign.altText,
            ),
          ),
        ],
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
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in categories)
            SizedBox(
              width: 104 * catalogTextScale(context),
              child: Card(
                child: InkWell(
                  onTap: () => context.push(
                    '/search?mode=products&q=${Uri.encodeQueryComponent(category.name)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (category.imageUrl != null)
                          CatalogImage(
                            url: category.imageUrl,
                            discovery: widget.dependencies.discovery!,
                            width: 48,
                            height: 48,
                            label: category.name,
                          )
                        else
                          const Icon(Icons.category_outlined, size: 32),
                        const SizedBox(height: 8),
                        Text(category.name, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final product in products)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ProductCardTile(
                    width: 184 * catalogTextScale(context),
                    product: product,
                    discovery: widget.dependencies.discovery!,
                    onTap: () => context.push('/products/${product.id}'),
                  ),
                ),
            ],
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
        CatalogGrid(
          children: [
            for (final product in _controller.recommendations)
              ProductCardTile(
                width: double.infinity,
                product: product,
                discovery: widget.dependencies.discovery!,
                onTap: () => context.push('/products/${product.id}'),
              ),
          ],
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
