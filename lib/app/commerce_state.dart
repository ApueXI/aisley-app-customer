import 'dart:async';

import '../core/commerce/commerce_value.dart';
import '../core/security/session_controller.dart';
import '../features/addresses/data/address_repository.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/cart/presentation/cart_controller.dart';
import '../features/checkout/data/checkout_repository.dart';
import '../features/checkout/presentation/checkout_controller.dart';
import '../features/orders/data/order_repository.dart';
import '../features/orders/presentation/order_mutation_controller.dart';

class CommerceState {
  CommerceState({
    required this.session,
    required CartRepository carts,
    required CheckoutRepository checkoutRepository,
    required AddressRepository addresses,
    required this.orders,
    DateTime Function()? clock,
    String Function()? uuid,
  }) {
    cart = CartController(session, carts);
    checkout = CheckoutController(
      session,
      checkoutRepository,
      addresses,
      cart,
      clock: clock ?? DateTime.now,
      uuid: uuid ?? secureUuid,
    );
    mutations = OrderMutationController(
      session,
      orders,
      uuid: uuid ?? secureUuid,
    );
    cart.locked = () => checkout.pending != null || checkout.placing;
    cart.onChanged = checkout.onCartChanged;
    _active = session.active;
    session.addListener(_sessionChanged);
    if (_active) scheduleMicrotask(cart.load);
  }
  final SessionController session;
  final OrderRepository orders;
  late final CartController cart;
  late final CheckoutController checkout;
  late final OrderMutationController mutations;
  bool _active = false;
  void _sessionChanged() {
    if (_active == session.active) return;
    _active = session.active;
    if (!_active) {
      cart.stale = true;
      if (checkout.pending == null) checkout.invalidateQuote();
    } else {
      unawaited(cart.load());
    }
  }

  void dispose() {
    session.removeListener(_sessionChanged);
    cart.onChanged = null;
    checkout.dispose();
    cart.dispose();
    mutations.dispose();
  }
}
