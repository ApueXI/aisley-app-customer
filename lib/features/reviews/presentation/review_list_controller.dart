import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../data/review_repository.dart';
import '../data/review_models.dart';

class ReviewListController extends ChangeNotifier with RequestCooldown {
  ReviewListController(this.repository, this.product);
  final ReviewRepository repository;
  final String product;
  List<ProductReview> items = const [];
  bool loading = false, paging = false, loaded = false, hasMore = false;
  String? error, pageError;
  ReviewSummary? summary;
  int page = 0, generation = 0;
  bool disposed = false;
  Future<void> load({bool more = false}) async {
    if (loading || paging || coolingDown || more && !hasMore) return;
    final stamp = generation;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      error = null;
    }
    notifyListeners();
    try {
      final value = await repository.list(product, more ? page + 1 : 1);
      if (disposed || generation != stamp) return;
      if (value.page != (more ? page + 1 : 1)) {
        throw const ApiFailure(FailureKind.decode);
      }
      final old = items.map((e) => e.id).toSet();
      items = List.unmodifiable(
        {
          if (more)
            for (final e in items) e.id: e,
          for (final e in value.items) e.id: e,
        }.values,
      );
      hasMore =
          value.hasMore &&
          (!more || value.items.any((e) => !old.contains(e.id)));
      page = value.page;
      loaded = true;
      summary = value.summary;
    } on ApiFailure catch (e) {
      if (disposed || generation != stamp) return;
      if (more) {
        pageError = describeFailure(e);
      } else {
        error = describeFailure(e);
      }
      if (e.status == 403 || e.status == 404) {
        items = const [];
        hasMore = loaded = false;
      }
    } finally {
      if (!disposed && generation == stamp) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    super.dispose();
  }
}
