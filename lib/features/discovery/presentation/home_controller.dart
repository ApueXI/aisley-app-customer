import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
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
  final _trail = CursorTrail();
  String? get cursor => _trail.next;
  String? error, pageError;
  bool stale = true;
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
    _trail.clear();
    stale = true;
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
    if (home != null && _homeOwner != customerId) {
      home = null;
      recommendations = const [];
      _trail.clear();
      stale = true;
    }
    _homeOwner = customerId;
    loading = true;
    loadingMore = false;
    stale = true;
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
      _trail.clear();
      _trail.seed(
        recommendations.length >= 200
            ? null
            : result.recommendations.nextCursor,
      );
      stale = false;
    } on ApiFailure catch (failure) {
      if (_current(generation, epoch, lease)) {
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) {
          home = null;
          recommendations = const [];
          _trail.clear();
        }
      }
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
    if (_disposed ||
        stale ||
        !session.active ||
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
      final prior = recommendations.map((e) => e.id).toSet();
      recommendations = merged;
      _trail.advance(
        next,
        merged.length >= 200 ? null : page.nextCursor,
        progressed: page.items.any((e) => !prior.contains(e.id)),
      );
    } on ApiFailure catch (failure) {
      if (_current(generation, epoch, lease)) {
        pageError = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) {
          home = null;
          recommendations = const [];
          _trail.clear();
          stale = true;
          error = pageError;
          pageError = null;
        }
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
    return List.unmodifiable({for (final item in values) item.id: item}.values);
  }

  void clearPrivate() {
    _queryGeneration++;
    clearCooldown();
    if (_homeOwner != null) {
      home = null;
      recommendations = const [];
      _trail.clear();
      stale = true;
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
