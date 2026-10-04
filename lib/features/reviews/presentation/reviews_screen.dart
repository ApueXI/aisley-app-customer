import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../discovery/presentation/catalog_image.dart';
import '../data/review_models.dart';
import 'review_list_controller.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.dependencies,
    required this.product,
  });
  final AppDependencies dependencies;
  final String product;
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final controller = ReviewListController(
    widget.dependencies.communication!.reviews,
    widget.product,
  );
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Product reviews'),
        actions: [
          IconButton(
            tooltip: 'Refresh reviews',
            onPressed: controller.loading || controller.coolingDown
                ? null
                : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.loading)
              const LinearProgressIndicator(semanticsLabel: 'Loading reviews'),
            if (controller.error != null) ...[
              Text(controller.error!),
              TextButton(
                onPressed: controller.coolingDown ? null : controller.load,
                child: const Text('Retry'),
              ),
            ],
            if (controller.summary != null) ...[
              Text(
                '${controller.summary!.average?.toStringAsFixed(1) ?? 'No rating'} · ${controller.summary!.count} reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final entry in controller.summary!.distribution.entries)
                Text('${entry.key} stars: ${entry.value}'),
            ],
            const Text(
              'Reviews can be submitted from an eligible delivered Order item.',
            ),
            if (controller.loaded && controller.items.isEmpty)
              const Text('No reviews yet.'),
            for (final item in controller.items)
              ReviewView(review: item, dependencies: widget.dependencies),
            if (controller.pageError != null) Text(controller.pageError!),
            if (controller.hasMore)
              TextButton(
                onPressed:
                    controller.loading ||
                        controller.paging ||
                        controller.coolingDown
                    ? null
                    : () => controller.load(more: true),
                child: Text(
                  controller.paging ? 'Loading…' : 'Load more reviews',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ReviewView extends StatelessWidget {
  const ReviewView({
    super.key,
    required this.review,
    required this.dependencies,
    this.photos,
  });
  final List<ReviewPhoto>? photos;
  final ProductReview review;
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${review.rating} of 5 stars · ${review.author}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (review.verified) const Text('Verified purchase'),
        SelectableText(review.body),
        if (review.at != null) Text(review.at!.toLocal().toString()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in photos ?? review.photos)
              CatalogImage(
                url: photo.url,
                discovery: dependencies.discovery!,
                height: 120,
                width: 120,
                label: 'Review photo',
              ),
          ],
        ),
        if (review.response != null) ...[
          Text('Official response · ${review.response!.shopName}'),
          SelectableText(review.response!.body),
        ],
        const Divider(),
      ],
    ),
  );
}
