import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import '../../checkout/data/batch_models.dart';
import '../../checkout/data/commerce_address.dart';
import '../../checkout/data/voucher_models.dart';
import 'tracking_models.dart';

const orderGroups = [
  'to_pay',
  'to_prepare',
  'to_ship',
  'out_for_delivery',
  'completed',
  'cancelled_issue',
];
const orderStatuses = [
  'pending_payment',
  'placed',
  'seller_processing',
  'ready_for_pickup',
  'picked_up',
  'assigned',
  'in_transit',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'rejected',
  'delivery_failed',
  'return_requested',
  'returned',
];

class OrderActions {
  OrderActions.parse(Object? json) {
    final w = Wire(json);
    canCancel = w.boolean('canCancel');
    canModify = w.boolean('canModify');
    canReview = w.boolean('canReview');
    fields = w.strings('modifiableFields');
  }
  late final bool canCancel, canModify, canReview;
  late final List<String> fields;
}

class BuyerOrder {
  BuyerOrder.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    reference = w.string('reference');
    batchId = nullableUuid(w, 'checkoutBatchId');
    placedAt = requiredTime(w, 'placedAt');
    latestTrackingAt = requiredTime(w, 'latestTrackingAt');
    status = w.string('status');
    statusLabel = w.string('statusLabel');
    group = w.string('group');
    groupLabel = w.string('groupLabel');
    shop = CommerceShop.parse(w.object('shop'), order: true);
    items = w.list('items', (v) => SnapshotItem.parse(v, reviewable: true));
    address = CommerceAddress.parse(
      w.object('deliveryAddress'),
      delivery: true,
    );
    final payment = Wire(w.object('payment'));
    paymentMethod = payment.string('method');
    paymentStatus = payment.string('status');
    vouchers = w.list('vouchers', SnapshotVoucher.parse);
    totals = CommerceTotals.parse(w.object('totals'));
    timeline = w.list('timeline', TrackingEvent.parse);
    timelineCount = nonnegative(w, 'timelineCount');
    timelineHasMore = w.boolean('timelineHasMore');
    trackingUrl = w.string('trackingUrl');
    final rawDelivery = w.field('delivery');
    delivery = rawDelivery == null ? null : OrderDelivery.parse(rawDelivery);
    final map = Wire(w.object('map'));
    mapAvailable = map.boolean('available');
    mapState = map.string('state');
    mapMessage = map.string('message');
    for (final key in ['currentPosition', 'route', 'capturedAt']) {
      if (map.field(key) != null) throw const ApiFailure(FailureKind.decode);
    }
    actions = OrderActions.parse(w.object('actions'));
  }
  late final String id,
      reference,
      status,
      statusLabel,
      group,
      groupLabel,
      paymentMethod,
      paymentStatus,
      trackingUrl,
      mapState,
      mapMessage;
  late final String? batchId;
  late final DateTime placedAt, latestTrackingAt;
  late final CommerceShop shop;
  late final List<SnapshotItem> items;
  late final CommerceAddress address;
  late final List<SnapshotVoucher> vouchers;
  late final CommerceTotals totals;
  late final List<TrackingEvent> timeline;
  late final int timelineCount;
  late final bool timelineHasMore, mapAvailable;
  late final OrderDelivery? delivery;
  late final OrderActions actions;
  bool get supported =>
      orderStatuses.contains(status) &&
      orderGroups.contains(group) &&
      paymentMethod == 'cod';
  bool get canCancel =>
      supported &&
      status == 'placed' &&
      paymentStatus == 'pending' &&
      actions.canCancel;
  bool get canCorrect =>
      supported &&
      status == 'placed' &&
      paymentStatus == 'pending' &&
      actions.canModify &&
      actions.fields.contains('delivery_address');
}

class OrderDelivery {
  OrderDelivery.parse(Object? json) {
    final w = Wire(json);
    status = w.string('status');
    final raw = w.field('courier');
    final courier = raw == null ? null : Wire(raw);
    name = courier?.string('name');
    contact = courier?.nullableString('contactNumber');
  }
  late final String status;
  late final String? name, contact;
}

class OrderSummary {
  OrderSummary.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    reference = w.string('reference');
    shop = CommerceShop.parse(w.object('shop'), order: true);
    final preview = w.field('itemPreview');
    item = preview == null ? null : ItemPreview.parse(preview);
    lineCount = nonnegative(w, 'lineCount');
    itemCount = nonnegative(w, 'itemCount');
    status = w.string('status');
    statusLabel = w.string('statusLabel');
    group = w.string('group');
    groupLabel = w.string('groupLabel');
    latestTrackingAt = requiredTime(w, 'latestTrackingAt');
    totals = CommerceTotals.parse(w.object('totals'));
    actions = OrderActions.parse(w.object('actions'));
    detailUrl = w.string('detailUrl');
  }
  late final String id,
      reference,
      status,
      statusLabel,
      group,
      groupLabel,
      detailUrl;
  late final CommerceShop shop;
  late final ItemPreview? item;
  late final int lineCount, itemCount;
  late final DateTime latestTrackingAt;
  late final CommerceTotals totals;
  late final OrderActions actions;
}

class ItemPreview {
  ItemPreview.parse(Object? json) {
    final w = Wire(json);
    productId = nullableUuid(w, 'productId');
    name = w.string('productName');
    variantName = w.nullableString('variantName');
    quantity = w.positiveInt('quantity');
  }
  late final String? productId, variantName;
  late final String name;
  late final int quantity;
}
