import 'dart:async';

import '../../../core/commerce/commerce_controller.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../addresses/data/address_models.dart';
import '../../addresses/data/address_repository.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/batch_models.dart';
import '../data/checkout_repository.dart';
import '../data/quote_models.dart';
import '../domain/checkout_intent.dart';
import 'checkout_shipping_controller.dart';

class CheckoutController extends CommerceController {
  CheckoutController(
    super.session,
    this.repository,
    this.addressRepository,
    this.cart, {
    required this.clock,
    required this.uuid,
  }) {
    shipping = CheckoutShippingController(session, repository);
    shipping.addListener(notifyListeners);
  }
  late final CheckoutShippingController shipping;
  final CheckoutRepository repository;
  final AddressRepository addressRepository;
  final CartController cart;
  final DateTime Function() clock;
  final String Function() uuid;
  CheckoutIntent? intent;
  String? addressId;
  List<BuyerAddress> addresses = const [];
  List<VoucherSelection> vouchers = const [];
  CheckoutQuote? quote;
  CheckoutInput? _reviewedInput;
  CheckoutBatch? result;
  PendingPlacement? pending;
  // A later rejected attempt does not prove an earlier request rolled back.
  bool _placementUncertain = false;
  List<String> _pendingShopIds = const [];
  bool loadingAddresses = false, quoting = false, placing = false;
  bool addressesFresh = false, collision = false, cartChanged = false;
  int _query = 0;
  Timer? _expiry;
  bool get editable =>
      lease != null &&
      pending == null &&
      !loadingAddresses &&
      !quoting &&
      !placing &&
      !coolingDown;
  bool get expired => quote != null && !clock().isBefore(quote!.expiresAt);
  bool get canQuote =>
      editable &&
      addressesFresh &&
      addressId != null &&
      intent != null &&
      shipping.ready &&
      !cartChanged;
  bool get canPlace =>
      editable &&
      quote != null &&
      !expired &&
      _reviewedInput != null &&
      quote!.paymentMethod == 'cod' &&
      quote!.summary.currency == 'PHP' &&
      quote!.groups.every((g) => g.shipping.supported) &&
      !cartChanged;

  bool begin(CheckoutIntent value) {
    if (!editable) return false;
    intent = value;
    vouchers = const [];
    result = null;
    cartChanged = false;
    shipping.reset(preserveUnresolved: false);
    invalidateQuote();
    notifyListeners();
    if (addressesFresh && addressId != null) unawaited(loadShippingOptions());
    return true;
  }

  void invalidateQuote() {
    _query++;
    _expiry?.cancel();
    quote = null;
    _reviewedInput = null;
    quoting = false;
  }

  void onCartChanged() {
    if (intent?.mode != 'cart' || pending != null) return;
    cartChanged = true;
    shipping.invalidate();
    invalidateQuote();
    if (!disposed) notifyListeners();
  }

  void chooseAddress(String id) {
    if (!editable || !addressesFresh || !addresses.any((a) => a.id == id)) {
      return;
    }
    addressId = id;
    invalidateQuote();
    shipping.invalidate();
    notifyListeners();
    unawaited(loadShippingOptions());
  }

  void chooseProvider(String shopId, String organizationId) {
    final hadReview = quote != null;
    if (!editable || !shipping.select(shopId, organizationId)) return;
    invalidateQuote();
    error = hadReview
        ? 'Shipping provider changed. Review your order again before placing.'
        : null;
    fieldErrors = const {};
    notifyListeners();
  }

  Future<void> loadShippingOptions() async {
    if (!editable ||
        !addressesFresh ||
        addressId == null ||
        intent == null ||
        cartChanged) {
      return;
    }
    invalidateQuote();
    await shipping.load(CheckoutInput(intent!, addressId!, vouchers));
  }

  void chooseVoucher(
    QuoteGroup group,
    CheckoutVoucherCandidate candidate,
    bool selected,
  ) {
    // Only candidates from the current server quote are selectable.
    final currentQuote = quote;
    if (!editable || currentQuote == null) return;
    final found = group.candidates
        .where((v) => v.id == candidate.id && v.selectable)
        .firstOrNull;
    if (found == null || !currentQuote.groups.contains(group)) return;
    final next = vouchers.where((v) => v.voucherId != candidate.id).toList();
    if (selected) next.add(VoucherSelection(candidate.id, group.shop.id));
    if (next.length > 20) return;
    vouchers = List.unmodifiable(next);
    invalidateQuote();
    error = 'Voucher selection changed. Get a new quote and review the totals.';
    notifyListeners();
    unawaited(loadShippingOptions());
  }

  void removeVoucher(String id) {
    if (!editable) return;
    vouchers = List.unmodifiable(vouchers.where((v) => v.voucherId != id));
    invalidateQuote();
    notifyListeners();
    unawaited(loadShippingOptions());
  }

  Future<void> loadAddresses() async {
    final credential = lease;
    if (credential == null ||
        loadingAddresses ||
        pending != null ||
        coolingDown) {
      return;
    }
    final generation = epoch;
    loadingAddresses = true;
    addressesFresh = false;
    shipping.invalidate();
    invalidateQuote();
    error = null;
    notifyListeners();
    try {
      final rows = await addressRepository.list(credential);
      if (!current(generation, credential)) return;
      addresses = List.unmodifiable(
        rows.where((a) => const ['shipping', 'both'].contains(a.type)),
      );
      addressesFresh = true;
      if (!addresses.any((a) => a.id == addressId)) {
        addressId =
            addresses.where((a) => a.isDefault).firstOrNull?.id ??
            addresses.firstOrNull?.id;
      }
    } on ApiFailure catch (value) {
      if (current(generation, credential)) {
        if (value.status == 403 || value.status == 404) {
          addresses = const [];
          addressId = null;
        }
        failure(value);
      }
    } finally {
      if (current(generation, credential)) {
        loadingAddresses = false;
        notifyListeners();
      }
    }
    if (current(generation, credential) && addressesFresh) {
      await loadShippingOptions();
    }
  }

  Future<void> getQuote() async {
    final credential = lease;
    if (credential == null || !canQuote) return;
    final generation = epoch;
    invalidateQuote();
    final query = _query;
    final input = CheckoutInput(
      intent!,
      addressId!,
      vouchers,
      logisticsSelections: shipping.selections,
    );
    quoting = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.quote(credential, input);
      if (!current(generation, credential) || query != _query) return;
      _validateQuote(value, input);
      quote = value;
      _reviewedInput = input;
      final duration = value.expiresAt.difference(clock());
      if (duration > Duration.zero) {
        _expiry = Timer(duration, () {
          if (!disposed) notifyListeners();
        });
      }
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        failure(value);
        if (shippingFailureCodes.contains(value.code)) shipping.invalidate();
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        quoting = false;
        notifyListeners();
      }
    }
  }

  void _validateQuote(CheckoutQuote value, CheckoutInput input) {
    if (value.mode != input.intent.mode ||
        value.paymentMethod != 'cod' ||
        value.address.id != input.addressId ||
        value.groups.any(
          (group) => group.totals.currency != value.summary.currency,
        )) {
      throw const ApiFailure(FailureKind.decode);
    }
    final items = value.groups.expand((g) => g.items).toList();
    final optionsShopIds = shipping.options!.groups
        .map((g) => g.shop.id.toLowerCase())
        .toSet();
    if (value.groups.length != optionsShopIds.length ||
        !optionsShopIds.containsAll(
          value.groups.map((g) => g.shop.id.toLowerCase()),
        )) {
      throw const ApiFailure(FailureKind.decode);
    }
    for (final selection in input.logisticsSelections) {
      final group = value.groups
          .where((g) => g.shop.id.toLowerCase() == selection.shopId)
          .firstOrNull;
      if (group == null ||
          group.shipping.organizationId != selection.organizationId) {
        throw const ApiFailure(FailureKind.decode);
      }
    }
    if (input.intent.mode == 'cart') {
      final ids = items.map((i) => i.cartItemId).toSet();
      if (ids.length != items.length ||
          ids.length != input.intent.cartIds.length ||
          !ids.containsAll(input.intent.cartIds)) {
        throw const ApiFailure(FailureKind.decode);
      }
    } else {
      final item = input.intent.buyNow!;
      if (items.length != 1 ||
          items.single.productId != item.productId ||
          items.single.variantId != item.variantId ||
          items.single.quantity != item.quantity) {
        throw const ApiFailure(FailureKind.decode);
      }
    }
    final applied = [
      for (final group in value.groups)
        for (final voucher in group.applied) '${voucher.id}/${group.shop.id}',
    ];
    final selected = input.vouchers
        .map((v) => '${v.voucherId}/${v.shopId}')
        .toSet();
    if (applied.length != selected.length || !selected.containsAll(applied)) {
      throw const ApiFailure(FailureKind.decode);
    }
  }

  Future<CheckoutBatch?> place({CheckoutQuote? confirmedQuote}) async {
    if (confirmedQuote != null &&
        (!identical(confirmedQuote, quote) || expired)) {
      if (editable) {
        invalidateQuote();
        error = 'Your order review changed or expired. Review again before placing.';
        notifyListeners();
      }
      return null;
    }
    if (!canPlace) return null;
    _placementUncertain = false;
    pending = PendingPlacement(
      key: requireUuid(uuid()),
      payload: _reviewedInput!.toJson(quoteId: quote!.id),
      customerId: session.customer!.id,
      sessionGeneration: session.generation,
      cartMode: intent!.mode == 'cart',
    );
    _pendingShopIds = List.unmodifiable(quote!.groups.map((g) => g.shop.id));
    return _sendPending();
  }

  Future<CheckoutBatch?> retryPending() async {
    if (pending == null || collision || placing || coolingDown) return null;
    return _sendPending();
  }

  Future<CheckoutBatch?> _sendPending() async {
    final credential = lease, frozen = pending;
    if (credential == null ||
        frozen == null ||
        frozen.customerId != session.customer?.id ||
        frozen.sessionGeneration != session.generation) {
      return null;
    }
    final generation = epoch;
    final hadUncertainOutcome = _placementUncertain;
    // Until a current response is classified, an interrupted exchange is unresolved.
    _placementUncertain = true;
    placing = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.place(credential, frozen);
      if (!current(generation, credential)) return null;
      if (value.currency != 'PHP' ||
          value.orders.any(
            (order) =>
                order.paymentMethod != 'cod' ||
                order.totals.currency != value.currency,
          ) ||
          value.orders.length != _pendingShopIds.length ||
          !value.orders
              .map((o) => o.shop.id)
              .toSet()
              .containsAll(_pendingShopIds)) {
        throw const ApiFailure(FailureKind.decode);
      }
      result = value;
      pending = null;
      _placementUncertain = false;
      _pendingShopIds = const [];
      intent = null;
      vouchers = const [];
      shipping.reset(preserveUnresolved: false);
      invalidateQuote();
      if (frozen.cartMode) await cart.load();
      if (!current(generation, credential)) return null;
      return value;
    } on ApiFailure catch (value) {
      if (!current(generation, credential)) return null;
      failure(value);
      collision = const [
        'IDEMPOTENCY_KEY_REUSED',
        'QUOTE_ALREADY_PLACED',
      ].contains(value.code);
      final quoteRejected =
          value.status == 409 &&
          const [
            'QUOTE_EXPIRED',
            'QUOTE_INPUT_CHANGED',
            'QUOTE_STALE',
          ].contains(value.code);
      _placementUncertain = hadUncertainOutcome || value.uncertain;
      // Resource denial clears projections, not an earlier unresolved request.
      if (value.status == 403 || value.status == 404) {
        addresses = const [];
        addressId = null;
        addressesFresh = false;
        vouchers = const [];
        shipping.reset(preserveUnresolved: false);
        invalidateQuote();
      }
      if (collision || (_placementUncertain && !quoteRejected)) {
        error = collision
            ? 'Placement could not be reconciled. Check Orders; another placement is blocked.'
            : value.status == 429
            ? 'The service is limiting requests. Your earlier order is still unconfirmed. Wait before retrying the exact placement; do not place another order.'
            : 'The placement outcome is uncertain. Retry the exact request to check it; do not place another order.';
      } else {
        pending = null;
        _placementUncertain = false;
        _pendingShopIds = const [];
        invalidateQuote();
        if (shippingFailureCodes.contains(value.code)) shipping.invalidate();
        error =
            '${value.description} Get a fresh quote and review before placing again.';
      }
      return null;
    } finally {
      if (!disposed && epoch == generation && credential.isCurrent()) {
        placing = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    invalidateQuote();
    if (!preserveUnresolved) {
      pending = null;
      _placementUncertain = false;
      _pendingShopIds = const [];
      collision = false;
    } else if (pending != null) {
      // A consent interruption can hide the response of an in-flight request.
      _placementUncertain = true;
    }
    intent = null;
    addressId = null;
    addresses = const [];
    vouchers = const [];
    result = null;
    loadingAddresses = placing = false;
    addressesFresh = false;
    cartChanged = false;
    shipping.reset(preserveUnresolved: false);
  }

  @override
  void dispose() {
    shipping.removeListener(notifyListeners);
    super.dispose();
    shipping.dispose();
  }
}

const shippingFailureCodes = {
  'LOGISTICS_SELECTION_REQUIRED',
  'LOGISTICS_SELECTION_INVALID',
  'LOGISTICS_PROVIDER_UNAVAILABLE',
  'SHIPPING_COVERAGE_UNAVAILABLE',
  'PICKUP_ADDRESS_REQUIRED',
  'SHIPPING_RATE_UNAVAILABLE',
  'LOGISTICS_RATE_NOT_ACCEPTED',
  'SHIPPING_DATA_REQUIRED',
  'SHIPPING_DIMENSIONS_UNSUPPORTED',
  'SHIPPING_WEIGHT_UNSUPPORTED',
  'ROUTE_RATE_LIMIT_EXCEEDED',
};

/// A small immutable selection reference; eligibility is checked against the quote.
class CheckoutVoucherCandidate {
  const CheckoutVoucherCandidate(this.id);
  final String id;
}
