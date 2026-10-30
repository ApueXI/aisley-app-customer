import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_page.dart';
import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';
import 'notification_models.dart';

class NotificationRepository {
  NotificationRepository(this.api);
  final ApiClient api;
  Future<BuyerNotificationPage> list(
    SessionLease lease,
    String status,
    String category,
    int page,
  ) async {
    final response = await api.request(
      'GET',
      'customer/notifications',
      lease: lease,
      queryParameters: {
        'status': status,
        if (category != 'all') 'category': category,
        'page': page,
        'per_page': 20,
      },
    );
    final result = ApiPage.parse(response, BuyerNotification.parse);
    final meta = Wire(response).object('meta');
    return BuyerNotificationPage(
      items: result.items,
      page: result.page,
      hasMore: result.hasMore,
      categories: buyerNotificationCategoryCatalog(meta['categories']),
    );
  }

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
