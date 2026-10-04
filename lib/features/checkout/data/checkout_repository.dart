import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import '../domain/checkout_intent.dart';
import 'batch_models.dart';
import 'quote_models.dart';

class CheckoutRepository {
  CheckoutRepository(this.api);
  final ApiClient api;
  Future<CheckoutQuote> quote(SessionLease lease, CheckoutInput input) async =>
      CheckoutQuote.parse(
        Wire(
          await api.request(
            'POST',
            'customer/checkout/quote',
            body: input.toJson(),
            lease: lease,
          ),
        ).object('data'),
      );
  Future<CheckoutBatch> place(
    SessionLease lease,
    PendingPlacement pending,
  ) async => CheckoutBatch.parse(
    Wire(
      await api.request(
        'POST',
        'customer/checkout/place',
        body: pending.payload,
        lease: lease,
        idempotencyKey: pending.key,
      ),
    ).object('data'),
  );
  Future<CheckoutBatch> batch(SessionLease lease, String id) async =>
      CheckoutBatch.parse(
        Wire(
          await api.request(
            'GET',
            'customer/checkout/${requireUuid(id)}',
            lease: lease,
          ),
        ).object('data'),
      );
}
