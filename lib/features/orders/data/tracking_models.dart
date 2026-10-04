import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';

class TrackingEvent {
  TrackingEvent.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    status = w.string('status');
    label = w.string('label');
    eventType = w.nullableString('eventType');
    occurredAt = requiredTime(w, 'occurredAt');
    final raw = w.field('location');
    if (raw is List && raw.isEmpty) {
      hub = city = null;
    } else {
      final location = Wire(raw);
      hub = location.data.containsKey('hub') ? location.string('hub') : null;
      city = location.data.containsKey('city') ? location.string('city') : null;
    }
  }
  late final String id, status, label;
  late final String? eventType, hub, city;
  late final DateTime occurredAt;
}

/// Parse page envelopes, but never follow returned URLs with credentials.
class OrderPage<T> {
  OrderPage.parse(Object? json, T Function(Object?) parse) {
    final w = Wire(json);
    items = w.list('data', parse);
    final links = Wire(w.object('links'));
    links.string('first');
    links.string('last');
    links.nullableString('prev');
    links.nullableString('next');
    final meta = Wire(w.object('meta'));
    page = meta.positiveInt('current_page');
    lastPage = meta.positiveInt('last_page');
    perPage = meta.positiveInt('per_page');
    total = nonnegative(meta, 'total');
    meta.nullableInt('from');
    meta.nullableInt('to');
    meta.string('path');
    meta.list('links', (v) {
      final link = Wire(v);
      link.nullableString('url');
      link.string('label');
      link.boolean('active');
      return true;
    });
    if (page > 10000 || lastPage < page || perPage > 50) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final List<T> items;
  late final int page, lastPage, perPage, total;
  bool get hasMore => page < lastPage && page < 10000;
}

class OrderTab {
  OrderTab.parse(Object? json) {
    final w = Wire(json);
    value = w.nullableString('value');
    label = w.string('label');
  }
  late final String? value;
  late final String label;
}
