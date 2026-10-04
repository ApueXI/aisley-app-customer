import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_page.dart';
import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';
import 'notification_models.dart';

class NotificationRepository {
  NotificationRepository(this.api);
  final ApiClient api;
  Future<ApiPage<BuyerNotification>> list(
    SessionLease lease,
    String status,
    int page,
  ) async => ApiPage.parse(
    await api.request(
      'GET',
      'customer/notifications',
      lease: lease,
      queryParameters: {'status': status, 'page': page, 'per_page': 20},
    ),
    BuyerNotification.parse,
  );
  Future<BuyerNotification> detail(SessionLease lease, String id) async =>
      BuyerNotification.parse(
        Wire(
          await api.request(
            'GET',
            'customer/notifications/${requireUuid(id)}',
            lease: lease,
          ),
        ).object('data'),
      );
  Future<BuyerNotification> read(SessionLease lease, String id) async =>
      BuyerNotification.parse(
        Wire(
          await api.request(
            'POST',
            'customer/notifications/${requireUuid(id)}/read',
            lease: lease,
          ),
        ).object('data'),
      );
}
