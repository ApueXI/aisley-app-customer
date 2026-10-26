import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';

import '../support/fakes.dart';

void main() {
  test('assigned Order accepts direct authoritative delivery without invented intermediate history', () {
    final json =
        fixture('order-status', 'op-033')['data'] as Map<String, dynamic>;
    json['status'] = 'assigned';
    json['statusLabel'] = 'Assigned';
    json['group'] = 'to_ship';
    json['groupLabel'] = 'To ship';
    final before = BuyerOrder.parse(json);
    expect(before.status, 'assigned');
    final originalCount = before.timeline.length;
    // Driver submission has no Buyer mutation. Only a later Order read changes status.
    expect(before.status, 'assigned');
    json['status'] = 'delivered';
    json['statusLabel'] = 'Delivered';
    json['group'] = 'completed';
    json['groupLabel'] = 'Completed';
    json['payment']['status'] = 'paid';
    json['actions']['canReview'] = true;
    final after = BuyerOrder.parse(json);
    expect(after.status, 'delivered');
    expect(after.group, 'completed');
    expect(after.paymentStatus, 'paid');
    expect(after.actions.canReview, true);
    expect(after.timeline.length, originalCount);
  });
}
