import 'catalog_models.dart';

class ProductSearchPage {
  const ProductSearchPage({required this.items, required this.pagination});
  final List<ProductCard> items;
  final Pagination pagination;
}

class ShopSearchPage {
  const ShopSearchPage({required this.items, required this.pagination});
  final List<ShopSummary> items;
  final Pagination pagination;
}

class ShopDirectoryPage {
  const ShopDirectoryPage({
    required this.items,
    required this.categories,
    required this.pagination,
  });
  final List<ShopSummary> items;
  final List<Category> categories;
  final Pagination pagination;
}

class ShopProductPage {
  const ShopProductPage({
    required this.shop,
    required this.categories,
    required this.items,
    required this.pagination,
  });
  final ShopSummary shop;
  final List<Category> categories;
  final List<ProductCard> items;
  final Pagination pagination;
}
