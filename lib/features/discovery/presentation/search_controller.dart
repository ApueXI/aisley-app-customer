import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/discovery_page_models.dart';
import '../data/discovery_repository.dart';

enum SearchMode { products, shops }

class DiscoverySearchController extends PrivateFeatureController {
  DiscoverySearchController(this.repository) : super(repository.session);
  final DiscoveryRepository repository;
  SearchMode mode = SearchMode.products;
  String query = '';
  int pageNumber = 1, limit = 20;
  ProductSearchPage? products;
  ShopSearchPage? shops;
  bool loading = false;
  bool stale = true;
  Object? _baseSignature;
  Object? _requestSignature;
  int? get displayedPage =>
      products?.pagination.currentPage ?? shops?.pagination.currentPage;

  bool get hasQuery => query.isNotEmpty;
  bool get pageOutOfRange => switch (mode) {
    SearchMode.products =>
      products != null && pageNumber > products!.pagination.lastPage,
    SearchMode.shops =>
      shops != null && pageNumber > shops!.pagination.lastPage,
  };

  void setMode(SearchMode value) {
    if (value == mode) return;
    loading = false;
    stale = true;
    mode = value;
    pageNumber = 1;
    products = null;
    shops = null;
    error = null;
    featureGeneration++;
    notifyListeners();
  }

  Future<void> search(
    String rawQuery, {
    int page = 1,
    bool refresh = false,
  }) async {
    final lease = currentLease;
    if (lease == null || isDisposed) return;
    final normalized = rawQuery.trim();
    if (normalized.isEmpty) {
      query = '';
      pageNumber = 1;
      products = null;
      shops = null;
      error = null;
      loading = false;
      featureGeneration++;
      notifyListeners();
      return;
    }
    if (normalized.length > 100 || page < 1 || page > 10000) {
      featureGeneration++;
      products = null;
      shops = null;
      loading = false;
      error = 'Use a query up to 100 characters and a page from 1 to 10,000.';
      notifyListeners();
      return;
    }
    final base = (normalized, mode, limit);
    final request = (base, page);
    if (loading && request == _requestSignature) return;
    if (base != _baseSignature) {
      products = null;
      shops = null;
    }
    _baseSignature = base;
    _requestSignature = request;
    query = normalized;
    pageNumber = page;
    if (coolingDown) {
      featureGeneration++;
      loading = false;
      stale = true;
      notifyListeners();
      return;
    }
    stale = true;
    error = null;
    loading = true;
    final generation = ++featureGeneration;
    notifyListeners();
    try {
      if (mode == SearchMode.products) {
        final result = await repository.searchProducts(
          query: normalized,
          page: page,
          limit: limit,
          refresh: refresh,
        );
        if (!isCurrentEpoch(generation, lease)) return;
        if (result.pagination.currentPage != page) {
          throw const ApiFailure(FailureKind.decode);
        }
        products = result;
        stale = false;
      } else {
        final result = await repository.searchShops(
          query: normalized,
          page: page,
          limit: limit,
          refresh: refresh,
        );
        if (!isCurrentEpoch(generation, lease)) return;
        if (result.pagination.currentPage != page) {
          throw const ApiFailure(FailureKind.decode);
        }
        shops = result;
        stale = false;
      }
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) {
          products = null;
          shops = null;
        }
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => search(query, page: pageNumber, refresh: true);

  @override
  void onClear() {
    _baseSignature = _requestSignature = null;
    products = null;
    shops = null;
    loading = false;
    stale = true;
    query = '';
    pageNumber = 1;
  }
}
