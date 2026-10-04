import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import 'address_models.dart';

class AddressRepository {
  AddressRepository(this.api);
  final ApiClient api;

  Future<List<BuyerAddress>> list(SessionLease lease) async {
    final response = await api.request(
      'GET',
      'customer/addresses',
      lease: lease,
    );
    return Wire(response).list('data', BuyerAddress.parse);
  }

  Future<BuyerAddress> create(SessionLease lease, AddressInput input) async {
    final response = await api.request(
      'POST',
      'customer/addresses',
      body: input.toJson(),
      lease: lease,
    );
    return BuyerAddress.parse(Wire(response).object('data'));
  }

  Future<BuyerAddress> update(
    SessionLease lease,
    String id,
    AddressInput input,
  ) async {
    final response = await api.request(
      'PATCH',
      'customer/addresses/${Uri.encodeComponent(id)}',
      body: input.toJson(),
      lease: lease,
    );
    return BuyerAddress.parse(Wire(response).object('data'));
  }

  Future<void> delete(SessionLease lease, String id) async {
    await api.request(
      'DELETE',
      'customer/addresses/${Uri.encodeComponent(id)}',
      lease: lease,
    );
  }
}
