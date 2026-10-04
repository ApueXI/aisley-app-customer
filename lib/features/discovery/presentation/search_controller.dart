import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../data/discovery_page_models.dart';
import '../data/discovery_repository.dart';

enum SearchMode { products, shops }

class DiscoverySearchController extends ChangeNotifier with RequestCooldown {
  DiscoverySearchController(this.repository);
  final DiscoveryRepository repository;
  SearchMode mode = SearchMode.products;
  String query = '';
  int pageNumber = 1, limit = 20;
  ProductSearchPage? products;
  ShopSearchPage? shops;
  String? error;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;

  bool get hasQuery => query.isNotEmpty;
  bool get pageOutOfRange => switch (mode) {
    SearchMode.products =>
      products != null && pageNumber > products!.pagination.lastPage,
    SearchMode.shops =>
      shops != null && pageNumber > shops!.pagination.lastPage,
  };

  void setMode(SearchMode value) {
    if (value == mode) return;
    mode = value;
    pageNumber = 1;
    products = null;
    shops = null;
    error = null;
    _generation++;
    notifyListeners();
  }

  Future<void> search(String rawQuery, {int page = 1}) async {
    if (coolingDown) return;
    final normalized = rawQuery.trim();
    if (normalized.isEmpty) {
      query = '';
      pageNumber = 1;
      products = null;
      shops = null;
      error = null;
      loading = false;
      _generation++;
      notifyListeners();
      return;
    }
    if (normalized.length > 100 || page < 1 || page > 10000) {
      _generation++;
      products = null;
      shops = null;
      loading = false;
      error = 'Use a query up to 100 characters and a page from 1 to 10,000.';
      notifyListeners();
      return;
    }
    query = normalized;
    pageNumber = page;
    products = null;
    shops = null;
    error = null;
    loading = true;
    final generation = ++_generation;
    notifyListeners();
    try {
      if (mode == SearchMode.products) {
        final result = await repository.searchProducts(
          query: normalized,
          page: page,
          limit: limit,
        );
        if (_disposed || generation != _generation) return;
        products = result;
      } else {
        final result = await repository.searchShops(
          query: normalized,
          page: page,
          limit: limit,
        );
        if (_disposed || generation != _generation) return;
        shops = result;
      }
    } on ApiFailure catch (failure) {
      if (!_disposed && generation == _generation) {
        error = describeFailure(failure);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => search(query, page: pageNumber);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
