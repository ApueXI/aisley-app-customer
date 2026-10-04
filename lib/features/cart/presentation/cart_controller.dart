import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../data/cart_models.dart';
import '../data/cart_repository.dart';

class CartController extends CommerceController {
  CartController(super.session, this.repository);
  final CartRepository repository;
  BuyerCart? cart;
  Set<String> _selection = {};
  Set<String> get selection => Set.unmodifiable(_selection);
  bool loading = false, writing = false, stale = true, uncertain = false;
  bool Function() locked = () => false;
  void Function()? onChanged;
  bool get canEdit =>
      lease != null &&
      !loading &&
      !writing &&
      !stale &&
      !uncertain &&
      !coolingDown &&
      !locked();
  int? get badge => session.active && !stale ? cart?.itemCount : null;

  void select(String id, bool selected) {
    if (!canEdit ||
        cart?.items.any((line) => line.id == id && line.selectable) != true) {
      return;
    }
    if (selected) {
      _selection.add(id);
    } else {
      _selection.remove(id);
    }
    onChanged?.call();
    notifyListeners();
  }

  void _replace(BuyerCart value) {
    cart = value;
    _selection = _selection.intersection(
      value.items.where((row) => row.selectable).map((row) => row.id).toSet(),
    );
    stale = false;
    onChanged?.call();
  }

  Future<void> load() async {
    final credential = lease;
    if (credential == null || loading || writing || coolingDown) return;
    final generation = epoch;
    loading = true;
    stale = true;
    error = null;
    onChanged?.call();
    notifyListeners();
    try {
      final value = await repository.read(credential);
      if (!current(generation, credential)) return;
      _replace(value);
      if (uncertain) {
        error = 'Cart checked again. Review quantities before another action.';
      }
      uncertain = false;
    } on ApiFailure catch (value) {
      if (current(generation, credential)) {
        if (value.status == 403 || value.status == 404) {
          cart = null;
          _selection.clear();
        }
        failure(value);
      }
    } finally {
      if (!disposed && epoch == generation && credential.isCurrent()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> add(String productId, String? variantId, int quantity) async {
    // A first additive action does not depend on a cached Cart; uncertain state does.
    if (lease == null ||
        loading ||
        writing ||
        uncertain ||
        coolingDown ||
        locked()) {
      return false;
    }
    return _write(
      (credential) =>
          repository.add(credential, productId, variantId, quantity),
    );
  }

  Future<bool> update(
    String id, {
    int? quantity,
    String? variantId,
    bool changeVariant = false,
  }) async {
    if (!canEdit) return false;
    return _write(
      (credential) => repository.update(
        credential,
        id,
        quantity: quantity,
        variantId: variantId,
        changeVariant: changeVariant,
      ),
    );
  }

  Future<bool> remove(String id) async {
    if (!canEdit) return false;
    return _write((credential) => repository.remove(credential, id));
  }

  Future<bool> _write(Future<BuyerCart> Function(SessionLease) action) async {
    final credential = lease;
    if (credential == null) return false;
    final generation = epoch;
    writing = true;
    error = null;
    fieldErrors = const {};
    onChanged?.call();
    notifyListeners();
    try {
      final value = await action(credential);
      if (!current(generation, credential)) return false;
      _replace(value);
      return true;
    } on ApiFailure catch (value) {
      if (!current(generation, credential)) return false;
      failure(value);
      if (value.uncertain || value.status == 409 || value.status == 404) {
        stale = true;
        uncertain = value.uncertain;
        try {
          final fresh = await repository.read(credential);
          if (!current(generation, credential)) return false;
          _replace(fresh);
          uncertain = false;
          error = 'Cart checked again. Review quantities; the previous action was not repeated.';
        } on ApiFailure catch (readFailure) {
          if (current(generation, credential)) failure(readFailure);
        }
      } else if (value.status == 403) {
        cart = null;
        _selection.clear();
        stale = true;
      }
      return false;
    } finally {
      if (!disposed && epoch == generation && credential.isCurrent()) {
        if (!session.active) {
          uncertain = true;
          stale = true;
        }
        writing = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    uncertain = preserveUnresolved && (uncertain || writing);
    cart = null;
    _selection.clear();
    loading = writing = false;
    stale = true;
    onChanged?.call();
  }
}
