import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../data/discovery_page_models.dart';
import '../data/discovery_repository.dart';
import '../data/catalog_models.dart';

class ShopDirectoryController extends ChangeNotifier with RequestCooldown {
  ShopDirectoryController(this.repository);
  final DiscoveryRepository repository;
  ShopDirectoryPage? result;
  String? category, error;
  int page = 1, limit = 20;
  bool loading = false, _disposed = false;
  int _generation = 0;

  Future<void> load({bool reset = false}) async {
    if (loading || coolingDown) return;
    if (reset) page = 1;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.shops(
        category: category,
        page: page,
        limit: limit,
      );
      if (!_disposed && generation == _generation) result = value;
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

  Future<void> setCategory(String? value) async {
    if (value == category) return;
    category = value;
    page = 1;
    result = null;
    _generation++;
    loading = false;
    await load(reset: true);
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value > 10000 || loading) return;
    page = value;
    await load();
  }

  Future<void> retry() => load();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class ShopBrowseController extends ChangeNotifier with RequestCooldown {
  ShopBrowseController(
    this.repository, {
    required this.slug,
    required this.query,
    required this.category,
    required this.page,
    this.limit = 20,
  });
  final DiscoveryRepository repository;
  final String slug;
  String query;
  String? category;
  int page;
  final int limit;
  ShopProductPage? result;
  ShopSummary? shop;
  String? error;
  bool loading = false, _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    if (loading || coolingDown) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final shopValue = await repository.shop(slug);
      if (_disposed || generation != _generation) return;
      final value = await repository.shopProducts(
        slug: slug,
        query: query,
        category: category,
        page: page,
        limit: limit,
      );
      if (_disposed || generation != _generation) return;
      shop = shopValue;
      result = value;
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

  Future<void> setFilters({String? query, String? category}) async {
    if (query != null) this.query = query.trim();
    this.category = category;
    page = 1;
    result = null;
    shop = null;
    _generation++;
    loading = false;
    await load();
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value > 10000 || loading) return;
    page = value;
    await load();
  }

  Future<void> retry() => load();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
