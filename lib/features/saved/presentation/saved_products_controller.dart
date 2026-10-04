import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../../discovery/data/catalog_models.dart';
import '../data/saved_repository.dart';
import 'saved_status_controller.dart';

enum SavedCollection { wishlist, recentlyViewed }

class SavedProduct {
  const SavedProduct(this.product, this.date);
  final ProductCard product;
  final DateTime date;
}

class SavedProductsController extends PrivateFeatureController {
  SavedProductsController(
    super.session, {
    required this.collection,
    required this.wishlist,
    required this.recent,
    required this.savedStatus,
  });
  final SavedCollection collection;
  final WishlistRepository wishlist;
  final RecentlyViewedRepository recent;
  final SavedStatusController savedStatus;
  List<SavedProduct> items = const [];
  String? nextCursor;
  bool loading = false, loadingMore = false, clearing = false, loaded = false;
  final pending = <String>{};
  String? pageError;

  Future<void> load({bool more = false}) async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null ||
        coolingDown ||
        isDisposed ||
        loading ||
        loadingMore ||
        clearing ||
        pending.isNotEmpty) {
      return;
    }
    final cursor = more ? nextCursor : null;
    if (more && cursor == null) return;
    final epoch = more ? featureGeneration : ++featureGeneration;
    if (more) {
      loadingMore = true;
      pageError = null;
    } else {
      loading = true;
      error = null;
    }
    notifyListeners();
    try {
      List<SavedProduct> values;
      String? next;
      if (collection == SavedCollection.wishlist) {
        final page = await wishlist.page(lease, cursor: cursor);
        values = [
          for (final row in page.items) SavedProduct(row.product, row.savedAt),
        ];
        next = page.nextCursor;
      } else {
        final page = await recent.page(lease, cursor: cursor);
        values = [
          for (final row in page.items)
            SavedProduct(row.product, row.lastViewedAt),
        ];
        next = page.nextCursor;
      }
      if (!isCurrentEpoch(epoch, lease)) return;
      final unique = <String, SavedProduct>{};
      for (final item in [...(more ? items : <SavedProduct>[]), ...values]) {
        unique.putIfAbsent(item.product.id, () => item);
      }
      items = List.unmodifiable(unique.values);
      nextCursor = next == cursor ? null : next;
      loaded = true;
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(epoch, lease)) return;
      if (failure.status == 403 || failure.status == 404) {
        items = const [];
        nextCursor = null;
      }
      if (more) {
        pageError = describeFailure(failure);
      } else {
        error = describeFailure(failure);
      }
    } finally {
      if (isCurrentEpoch(epoch, lease)) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> remove(String productId) async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null ||
        coolingDown ||
        pending.isNotEmpty ||
        loading ||
        loadingMore ||
        clearing) {
      return;
    }
    final epoch = featureGeneration;
    pending.add(productId);
    error = null;
    notifyListeners();
    try {
      if (collection == SavedCollection.wishlist) {
        await savedStatus.setSaved(productId, false);
        if (!isCurrentEpoch(epoch, lease)) return;
        if (savedStatus.isSaved(productId) != false) {
          error =
              savedStatus.error ??
              'Removal could not be confirmed. Refresh to check.';
          return;
        }
      } else {
        await recent.remove(lease, productId);
      }
      if (isCurrentEpoch(epoch, lease)) {
        items = List.unmodifiable(
          items.where((item) => item.product.id != productId),
        );
      }
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(epoch, lease)) return;
      if (failure.uncertain) {
        pending.remove(productId);
        await load();
        if (lease.isCurrent() && session.active && !isDisposed) error = 'Removal was not confirmed. Review the refreshed history before another change.';
      } else {
        error = describeFailure(failure);
      }
    } finally {
      if (lease.isCurrent() && session.active && !isDisposed) {
        pending.remove(productId);
        notifyListeners();
      }
    }
  }

  Future<void> clearHistory() async {
    final lease = session.active ? session.verifiedLease : null;
    if (collection != SavedCollection.recentlyViewed ||
        lease == null ||
        clearing ||
        coolingDown ||
        loading ||
        loadingMore ||
        pending.isNotEmpty) {
      return;
    }
    final epoch = featureGeneration;
    clearing = true;
    error = null;
    notifyListeners();
    try {
      await recent.clear(lease);
      if (isCurrentEpoch(epoch, lease)) {
        items = const [];
        nextCursor = null;
        loaded = true;
      }
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(epoch, lease)) return;
      if (failure.uncertain) {
        clearing = false;
        await load();
        if (lease.isCurrent() && session.active && !isDisposed) error = 'Clearing was not confirmed. Review the refreshed history before another change.';
      } else {
        error = describeFailure(failure);
      }
    } finally {
      if (lease.isCurrent() && session.active && !isDisposed) {
        clearing = false;
        notifyListeners();
      }
    }
  }

  @override
  void onClear() {
    items = const [];
    nextCursor = null;
    pending.clear();
    loading = false;
    loadingMore = false;
    clearing = false;
    loaded = false;
    pageError = null;
  }
}
