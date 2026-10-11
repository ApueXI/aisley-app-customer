import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/discovery_page_models.dart';
import '../data/discovery_repository.dart';
import '../data/catalog_models.dart';

class ShopDirectoryController extends PrivateFeatureController {
  ShopDirectoryController(this.repository) : super(repository.session);
  final DiscoveryRepository repository;
  ShopDirectoryPage? result;
  String? category;
  int page = 1, limit = 20;
  bool loading = false, stale = true;
  Object? _baseSignature, _requestSignature;

  Future<void> load({bool reset = false, bool refresh = false}) async {
    final lease = currentLease;
    if (lease == null || isDisposed) return;
    final base = (category, limit);
    final request = (base, reset ? 1 : page);
    if (loading && request == _requestSignature) return;
    if (base != _baseSignature) result = null;
    _baseSignature = base;
    _requestSignature = request;
    if (coolingDown) {
      featureGeneration++;
      loading = false;
      stale = true;
      notifyListeners();
      return;
    }
    if (reset) page = 1;
    final generation = ++featureGeneration;
    loading = true;
    stale = true;
    final requestedPage = page;
    error = null;
    notifyListeners();
    try {
      final value = await repository.shops(
        category: category,
        page: requestedPage,
        limit: limit,
        refresh: refresh,
      );
      if (!isCurrentEpoch(generation, lease)) return;
      if (value.pagination.currentPage != requestedPage) {
        throw const ApiFailure(FailureKind.decode);
      }
      result = value;
      stale = false;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) result = null;
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
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
    featureGeneration++;
    loading = false;
    await load(reset: true);
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value > 10000) return;
    page = value;
    await load();
  }

  Future<void> retry() => load(refresh: true);

  @override
  void onClear() {
    _baseSignature = _requestSignature = null;
    result = null;
    loading = false;
    stale = true;
  }
}

class ShopBrowseController extends PrivateFeatureController {
  ShopBrowseController(
    this.repository, {
    required this.slug,
    required this.query,
    required this.category,
    required this.page,
    this.limit = 20,
  }) : super(repository.session);
  final DiscoveryRepository repository;
  final String slug;
  String query;
  String? category;
  int page;
  final int limit;
  ShopProductPage? result;
  ShopSummary? shop;
  bool loading = false, stale = true;
  Object? _baseSignature, _requestSignature;

  Future<void> load({bool refresh = false}) async {
    final lease = currentLease;
    if (lease == null || isDisposed) return;
    final base = (slug, query, category, limit);
    final request = (base, page);
    if (loading && request == _requestSignature) return;
    if (base != _baseSignature) result = null;
    _baseSignature = base;
    _requestSignature = request;
    if (coolingDown) {
      featureGeneration++;
      loading = false;
      stale = true;
      notifyListeners();
      return;
    }
    final generation = ++featureGeneration;
    loading = true;
    stale = true;
    final requestedPage = page;
    error = null;
    notifyListeners();
    try {
      final shopValue = await repository.shop(slug, refresh: refresh);
      if (!isCurrentEpoch(generation, lease)) return;
      final value = await repository.shopProducts(
        slug: slug,
        query: query,
        category: category,
        page: requestedPage,
        limit: limit,
        refresh: refresh,
      );
      if (!isCurrentEpoch(generation, lease)) return;
      if (value.pagination.currentPage != requestedPage) {
        throw const ApiFailure(FailureKind.decode);
      }
      stale = false;
      shop = shopValue;
      result = value;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) {
          result = null;
          shop = null;
        }
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
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
    featureGeneration++;
    loading = false;
    await load();
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value > 10000) return;
    page = value;
    await load();
  }

  Future<void> retry() => load(refresh: true);

  @override
  void onClear() {
    _baseSignature = _requestSignature = null;
    result = null;
    shop = null;
    loading = false;
    stale = true;
  }
}
