import '../../../core/commerce/commerce_controller.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../addresses/data/address_models.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

class OrderMutationController extends CommerceController {
  OrderMutationController(super.session, this.repository, {required this.uuid});
  final OrderRepository repository;
  final String Function() uuid;
  final _pending = <String, PendingOrderMutation>{};
  final _busy = <String>{};
  final _collisions = <String>{};
  final _errors = <String, String>{};
  final _conflicts = <String>{};
  PendingOrderMutation? pending(String id) => _pending[id];
  bool busy(String id) => _busy.contains(id);
  bool collision(String id) => _collisions.contains(id);
  String? errorFor(String id) => _errors[id];
  bool needsRefresh(String id) => _conflicts.contains(id);
  void refreshed(String id) {
    _conflicts.remove(id);
  }

  Future<BuyerOrder?> cancel(
    BuyerOrder order,
    String? reason, {
    required bool fresh,
  }) async {
    if (!fresh || !order.canCancel || !canStart(order.id)) return null;
    final text = reason?.trim();
    if (text != null && text.length > 500) return null;
    return _begin(order, false, {
      'reason': text == null || text.isEmpty ? null : text,
    });
  }

  Future<BuyerOrder?> correct(
    BuyerOrder order,
    BuyerAddress address, {
    required bool fresh,
    required bool owned,
  }) async {
    if (!fresh ||
        !owned ||
        !order.canCorrect ||
        !canStart(order.id) ||
        !order.address.permitsContactCorrection(address)) {
      return null;
    }
    return _begin(order, true, {
      'address_id': address.id,
      'expected_revision': order.address.version,
    });
  }

  bool canStart(String id) =>
      lease != null &&
      !coolingDown &&
      !_pending.containsKey(id) &&
      !_busy.contains(id) &&
      !_conflicts.contains(id);
  Future<BuyerOrder?> _begin(
    BuyerOrder order,
    bool correction,
    Map<String, dynamic> payload,
  ) {
    _pending[order.id] = PendingOrderMutation(
      orderId: order.id,
      key: requireUuid(uuid()),
      payload: payload,
      customerId: session.customer!.id,
      sessionGeneration: session.generation,
      correction: correction,
    );
    return retry(order.id);
  }

  Future<BuyerOrder?> retry(String id) async {
    final credential = lease, frozen = _pending[id];
    if (credential == null ||
        frozen == null ||
        _busy.contains(id) ||
        coolingDown ||
        _collisions.contains(id) ||
        frozen.customerId != session.customer?.id ||
        frozen.sessionGeneration != session.generation) {
      return null;
    }
    final generation = epoch;
    _busy.add(id);
    _errors.remove(id);
    notifyListeners();
    try {
      final value = await repository.mutate(credential, frozen);
      if (!current(generation, credential)) return null;
      _pending.remove(id);
      _conflicts.remove(id);
      return value;
    } on ApiFailure catch (value) {
      if (!current(generation, credential)) return null;
      failure(value);
      _errors[id] = error!;
      if (value.uncertain) {
        _errors[id] = 'The outcome is uncertain. Retry the exact request before another change.';
      } else if (value.code == 'IDEMPOTENCY_KEY_REUSED') {
        _collisions.add(id);
        _errors[id] = 'This request could not be reconciled. Refresh the Order; another change is blocked.';
      } else {
        _pending.remove(id);
        _conflicts.add(id);
      }
      return null;
    } finally {
      if (!disposed && generation == epoch && credential.isCurrent()) {
        _busy.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    if (!preserveUnresolved) {
      _pending.clear();
      _collisions.clear();
    }
    _busy.clear();
    _errors.clear();
    _conflicts.clear();
  }
}
