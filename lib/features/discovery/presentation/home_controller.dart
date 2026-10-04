import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/security/session_controller.dart';
import '../../saved/data/saved_repository.dart';
import '../data/catalog_models.dart';
import '../data/discovery_repository.dart';
import '../data/home_models.dart';

class HomeController extends ChangeNotifier with RequestCooldown {
  HomeController({
    required this.discovery,
    required this.session,
    required this.recentlyViewed,
  }) {
    session.registerPrivateCleanup(clearPrivate);
    _sessionStamp = _stamp;
    session.addListener(_sessionChanged);
  }
  final DiscoveryRepository discovery;
  final SessionController session;
  final RecentlyViewedRepository recentlyViewed;
  BuyerHome? home;
  List<ProductCard> recommendations = const [];
  String? cursor, error, pageError;
  bool loading = false, loadingMore = false;
  int _queryGeneration = 0;
  bool _disposed = false;

  bool get hasMore => cursor != null && recommendations.length < 200;
  String get _stamp =>
      '${session.generation}:${session.active ? session.customer?.id : 'public'}';

  String _sessionStamp = '';

  void _sessionChanged() {
    if (_disposed || _sessionStamp == _stamp) return;
    _sessionStamp = _stamp;
    _queryGeneration++;
    home = null;
    recommendations = const [];
    cursor = null;
    error = null;
    pageError = null;
    loading = false;
    loadingMore = false;
    _homeOwner = null;
    notifyListeners();
    unawaited(load(refresh: true));
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed || !session.active || loading || coolingDown) return;
    final lease = session.active ? session.verifiedLease : null;
    final generation = ++_queryGeneration;
    final epoch = session.generation;
    final customerId = lease == null ? null : session.customer?.id;
    if (refresh || home != null && _homeOwner != customerId) {
      home = null;
      recommendations = const [];
      cursor = null;
    }
    _homeOwner = customerId;
    loading = true;
    error = null;
    pageError = null;
    notifyListeners();
    try {
      final result = await discovery.home(refresh: refresh);
      if (!_current(generation, epoch, lease)) return;
      home = result;
      recommendations = _unique(result.recommendations.items)
          .take(200)
          .toList();
      cursor = recommendations.length >= 200
          ? null
          : result.recommendations.nextCursor;
    } on ApiFailure catch (failure) {
      if (_current(generation, epoch, lease)) error = describeFailure(failure);
    } finally {
      if (_current(generation, epoch, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  String? _homeOwner;

  Future<void> loadMore() async {
    final next = cursor;
    if (!session.active ||
        coolingDown ||
        loading ||
        loadingMore ||
        next == null ||
        recommendations.length >= 200) {
      return;
    }
    final lease = session.active ? session.verifiedLease : null;
    final generation = _queryGeneration, epoch = session.generation;
    loadingMore = true;
    pageError = null;
    notifyListeners();
    try {
      final page = await discovery.recommendations(cursor: next);
      if (!_current(generation, epoch, lease)) return;
      final merged = _unique([...recommendations, ...page.items])
          .take(200)
          .toList();
      recommendations = merged;
      cursor = merged.length >= 200 || page.nextCursor == next
          ? null
          : page.nextCursor;
    } on ApiFailure catch (failure) {
      if (_current(generation, epoch, lease)) {
        pageError = describeFailure(failure);
      }
    } finally {
      if (_current(generation, epoch, lease)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> recordViewed(String productId) async {
    final lease = session.active ? session.verifiedLease : null;
    try {
      if (lease != null) {
        await recentlyViewed.record(lease, productId);
      }
    } catch (_) {
      // A failed history write never turns a visible Product into an error page.
    }
  }

  bool _current(int generation, int epoch, SessionLease? lease) =>
      !_disposed &&
      generation == _queryGeneration &&
      epoch == session.generation &&
      (session.active && lease != null && lease.isCurrent());

  List<ProductCard> _unique(Iterable<ProductCard> values) {
    final found = <String>{};
    return [
      for (final item in values)
        if (found.add(item.id)) item,
    ];
  }

  void clearPrivate() {
    _queryGeneration++;
    clearCooldown();
    if (_homeOwner != null) {
      home = null;
      recommendations = const [];
      cursor = null;
      _homeOwner = null;
      error = null;
      pageError = null;
      loading = false;
      loadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.unregisterPrivateCleanup(clearPrivate);
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
