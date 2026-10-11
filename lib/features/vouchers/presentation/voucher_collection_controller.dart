import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/customer_voucher.dart';
import '../data/voucher_repository.dart';

/// Session-owned collection mutations survive route changes, with no write queue.
class VoucherCollectionController extends PrivateFeatureController {
  VoucherCollectionController(super.session, this.repository);
  final VoucherRepository repository;
  final _statuses = <String, CustomerVoucher>{};
  final _stamps = <String, Object>{};
  final _pending = <String>{};
  final _uncertain = <String, CustomerVoucher>{};
  final _errors = <String, String>{};
  final _denied = <String>{};
  bool denied(String id) => _denied.contains(id);
  int revision = 0;
  CustomerVoucher? status(String id) => _statuses[id];
  bool pending(String id) => _pending.contains(id);
  bool uncertain(String id) => _uncertain.containsKey(id);
  String? errorFor(String id) => _errors[id];

  Future<List<CustomerVoucher>> refresh(List<String> ids) async {
    final lease = currentLease;
    if (lease == null || isDisposed) return const [];
    final generation = featureGeneration;
    final stamps = {for (final id in ids) id: _stamps[id] = Object()};
    try {
      final rows = await repository.statuses(lease, ids);
      if (!isCurrentEpoch(generation, lease)) return const [];
      for (final id in ids) {
        if (identical(stamps[id], _stamps[id])) {
          _statuses.remove(id);
          final row = rows.where((v) => v.id == id).firstOrNull;
          if (row != null) {
            _remember(row);
            _denied.remove(id);
          }
        }
      }
      notifyListeners();
      return rows;
    } finally {
      for (final id in ids) {
        if (identical(stamps[id], _stamps[id])) _stamps.remove(id);
      }
    }
  }

  void _remember(CustomerVoucher row) {
    _statuses.remove(row.id);
    _statuses[row.id] = row;
    while (_statuses.length > 200) {
      _statuses.remove(_statuses.keys.first);
    }
  }

  Future<void> collect(CustomerVoucher voucher) async {
    final lease = currentLease;
    final retry = _uncertain[voucher.id];
    final current = _statuses[voucher.id] ?? voucher;
    if (lease == null ||
        isDisposed ||
        coolingDown ||
        pending(voucher.id) ||
        denied(voucher.id) ||
        retry == null && !current.collectable) {
      return;
    }
    final generation = featureGeneration;
    final stamp = _stamps[voucher.id] = Object();
    _pending.add(voucher.id);
    _errors.remove(voucher.id);
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.collect(lease, retry ?? current);
      if (!isCurrentEpoch(generation, lease)) return;
      _stamps.remove(voucher.id);
      _remember(value);
      _uncertain.remove(voucher.id);
      revision++;
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(generation, lease)) return;
      _errors[voucher.id] = failure.code?.startsWith('VOUCHER_') == true
          ? voucherReason(failure.code)
          : describeFailure(failure);
      // Cooldown also applies when an endpoint returns a business error.
      if (failure.retryAt != null) describeFailure(failure);
      fieldErrors = validationFields(failure);
      if (failure.uncertain || retry != null) {
        _uncertain[voucher.id] = retry ?? current;
        _errors[voucher.id] =
            '${_errors[voucher.id]} Collection is not confirmed. Retry the same collection.';
      }
      if (failure.status == 403 || failure.status == 404) {
        _statuses.remove(voucher.id);
        _uncertain.remove(voucher.id);
        _denied.add(voucher.id);
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        if (identical(_stamps[voucher.id], stamp)) {
          _stamps.remove(voucher.id);
        }
        _pending.remove(voucher.id);
        notifyListeners();
      }
    }
  }

  @override
  void onClear() {
    _statuses.clear();
    _stamps.clear();
    _pending.clear();
    _uncertain.clear();
    _errors.clear();
    _denied.clear();
    revision++;
  }
}
