import 'dart:async';

import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/customer_voucher.dart';
import '../data/voucher_repository.dart';
import 'voucher_collection_controller.dart';

class VoucherListController extends PrivateFeatureController {
  VoucherListController(
    super.session,
    this.repository,
    this.collection, {
    this.wallet = false,
    this.shopSlug,
  }) {
    _collectionRevision = collection.revision;
    collection.addListener(_collectionChanged);
  }
  final VoucherRepository repository;
  final VoucherCollectionController collection;
  final bool wallet;
  final String? shopSlug;
  String? issuer, benefit;
  String status = 'available';
  int page = 1;
  VoucherPage? result;
  bool loading = false, stale = true;
  String? statusError;
  Object? _base, _signature;
  late int _collectionRevision;

  void _collectionChanged() {
    if (_collectionRevision == collection.revision) return;
    _collectionRevision = collection.revision;
    if (!isDisposed && currentLease != null) unawaited(load(refresh: true));
  }

  Future<void> load({bool refresh = false}) async {
    final lease = currentLease;
    if (lease == null || isDisposed || coolingDown) return;
    final base = (shopSlug, wallet, issuer, benefit, status);
    final signature = (base, page);
    if (loading && _signature == signature && !refresh) return;
    if (_base != base) result = null;
    _base = base;
    _signature = signature;
    final generation = ++featureGeneration;
    final requestedPage = page;
    loading = true;
    stale = true;
    error = statusError = null;
    notifyListeners();
    try {
      final value = wallet
          ? await repository.mine(
              lease,
              issuer: issuer,
              benefit: benefit,
              status: status,
              page: requestedPage,
            )
          : await repository.list(
              shopSlug: shopSlug,
              issuer: issuer,
              benefit: benefit,
              page: requestedPage,
              refresh: refresh,
            );
      if (!isCurrentEpoch(generation, lease)) return;
      if (value.pagination.currentPage != requestedPage) {
        throw const ApiFailure(FailureKind.decode);
      }
      result = value;
      stale = false;
      if (!wallet && value.items.isNotEmpty) {
        try {
          await collection.refresh(value.items.map((v) => v.id).toList());
        } on ApiFailure catch (failure) {
          if (isCurrentEpoch(generation, lease)) {
            statusError = describeFailure(failure);
            if (failure.status == 403 || failure.status == 404) result = null;
          }
        }
      }
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        error = describeFailure(failure);
        fieldErrors = validationFields(failure);
        if (failure.status == 403 || failure.status == 404) result = null;
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> filters({String? issuer, String? benefit, String? status}) {
    this.issuer = issuer;
    this.benefit = benefit;
    this.status = status ?? this.status;
    page = 1;
    return load();
  }

  Future<void> setPage(int value) {
    if (value < 1 || value > 10000) return Future.value();
    page = value;
    return load();
  }

  @override
  void onClear() {
    result = null;
    loading = false;
    stale = true;
    statusError = null;
    _base = _signature = null;
  }

  @override
  void dispose() {
    collection.removeListener(_collectionChanged);
    super.dispose();
  }
}
