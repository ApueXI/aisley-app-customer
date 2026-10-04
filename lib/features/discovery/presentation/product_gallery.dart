import 'package:flutter/material.dart';

import '../data/discovery_repository.dart';
import '../data/product_detail_model.dart';
import 'catalog_image.dart';

class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.product,
    required this.variant,
    required this.discovery,
  });
  final ProductDetail product;
  final ProductVariant? variant;
  final DiscoveryRepository discovery;
  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _pages = PageController();
  int _index = 0;
  List<ProductMedia> get _media {
    final selected = widget.product.media
        .where(
          (m) =>
              widget.variant == null ||
              m.variantId == null ||
              m.variantId == widget.variant!.id ||
              m.id == widget.variant!.primaryMediaId,
        )
        .toList();
    return selected.isEmpty ? widget.product.media : selected;
  }

  @override
  void didUpdateWidget(ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant?.id != widget.variant?.id) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: constraints.maxWidth.clamp(180.0, 480.0),
            child: media.isEmpty
                ? const Center(child: Icon(Icons.image_outlined, size: 64))
                : PageView.builder(
                    controller: _pages,
                    key: PageStorageKey('gallery-${widget.product.id}'),
                    itemCount: media.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CatalogImage(
                        url: media[i].url,
                        discovery: widget.discovery,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        label: media[i].altText.isEmpty
                            ? widget.product.title
                            : media[i].altText,
                      ),
                    ),
                  ),
          ),
        ),
        if (media.length > 1)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: _index > 0
                    ? () => _pages.previousPage(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Photo ${_index + 1} of ${media.length}'),
              IconButton(
                tooltip: 'Next photo',
                onPressed: _index < media.length - 1
                    ? () => _pages.nextPage(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
