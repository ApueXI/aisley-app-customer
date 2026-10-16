import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_models.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_controller.dart';

import '../support/fakes.dart';
import '../support/commerce_harness.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());

  Map<String, dynamic> snapshot(Object? lat, Object? lng) => {
    ...h.orderJson['data']['deliveryAddress'] as Map<String, dynamic>,
    'latitude': lat,
    'longitude': lng,
  };
  BuyerOrder order(Object? lat, Object? lng) => BuyerOrder.parse({
    ...h.orderJson['data'] as Map<String, dynamic>,
    'deliveryAddress': snapshot(lat, lng),
  });
  Map<String, dynamic> candidate(Object? lat, Object? lng) => {
    ...snapshot(lat, lng),
    'id': otherId,
    'type': 'shipping',
    'label': null,
    'recipientName': 'Corrected recipient',
    'isDefault': false,
  };

  for (final scenario in [
    (
      'equal numeric/string pins',
      '14.1234567',
      '121.1234567',
      14.1234567,
      121.1234567,
      true,
    ),
    (
      'equal storage precision',
      14.12345671,
      121.12345671,
      14.12345672,
      121.12345672,
      true,
    ),
    (
      'changed latitude',
      14.1234567,
      121.1234567,
      14.1234568,
      121.1234567,
      false,
    ),
    (
      'changed longitude',
      14.1234567,
      121.1234567,
      14.1234567,
      121.1234568,
      false,
    ),
    ('both null', null, null, null, null, true),
    ('removed pin', 14.0, 121.0, null, null, false),
    ('added pin', null, null, 14.0, 121.0, false),
    ('partial snapshot', 14.0, null, 14.0, 121.0, false),
    ('out of range snapshot', 91.0, 121.0, 14.0, 121.0, false),
    ('signed zero', -0.0, 0.0, 0.0, -0.0, true),
  ]) {
    test(scenario.$1, () {
      final value = order(scenario.$2, scenario.$3);
      expect(
        value.address.permitsContactCorrection(
          BuyerAddress.parse(candidate(scenario.$4, scenario.$5)),
        ),
        scenario.$6,
      );
    });
  }

  test(
    'delivery parsing retains frozen pins and trims matching location text',
    () {
      final value = order('14.1234567', '121.1234567');
      expect(value.address.latitude, 14.1234567);
      expect(value.address.longitude, 121.1234567);
      final row = candidate(14.1234567, 121.1234567);
      for (final key in [
        'addressLine1',
        'barangay',
        'cityMunicipality',
        'province',
        'region',
        'postalCode',
        'country',
      ]) {
        row[key] = '  ${row[key]}  ';
      }
      row['addressLine2'] = '  ';
      expect(
        value.address.permitsContactCorrection(BuyerAddress.parse(row)),
        true,
      );
    },
  );

  test('detail filters pins, sends contact-only correction and refreshes frozen snapshot', () async {
    h.orderJson['data']['deliveryAddress'] = snapshot(
      '14.1234567',
      '121.1234567',
    );
    final valid = candidate(14.1234567, 121.1234567);
    h.reply = (r) {
      if (r.uri.path.endsWith('/addresses')) {
        return jsonReply({
          'data': [valid, candidate(null, null), candidate(15.0, 121.1234567)],
        });
      }
      if (r.uri.path.endsWith('/modification')) {
        h.orderJson['data']['deliveryAddress']['version'] = 2;
        h.orderJson['data']['deliveryAddress']['recipientName'] =
            valid['recipientName'];
      }
      return h.defaultReply(r);
    };
    final c = OrderDetailController(
      h.session,
      h.commerce.orders,
      h.commerce.mutations,
      AddressRepository(h.api),
      customerId,
    );
    addTearDown(c.dispose);
    await c.load();
    await c.loadAddresses();
    expect(c.addresses, hasLength(1));
    await c.correct(c.addresses.single);
    final write = h.adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(write.data, {'address_id': otherId, 'expected_revision': 1});
    expect(c.order!.address.version, 2);
    expect(c.order!.address.recipient, 'Corrected recipient');
    expect(c.order!.address.latitude, 14.1234567);
    expect(c.order!.address.longitude, 121.1234567);
    expect(c.addressesFresh, false);
    expect(h.commerce.mutations.pending(customerId), isNull);
  });

  test('location 422 refreshes detail, preserves feedback and requires reselecting saved rows', () async {
    h.orderJson['data']['deliveryAddress'] = snapshot(14.0, 121.0);
    var moved = false;
    h.reply = (r) {
      if (r.uri.path.endsWith('/addresses')) {
        return jsonReply({
          'data': [candidate(moved ? 15.0 : 14.0, 121.0)],
        });
      }
      if (r.uri.path.endsWith('/modification')) {
        moved = true;
        return jsonReply({
          'code': 'ADDRESS_LOCATION_CHANGE_NOT_ALLOWED',
          'errors': {
            'address_id': [
              'Select a saved address at the same location and map pin.',
            ],
          },
        }, status: 422);
      }
      return h.defaultReply(r);
    };
    final c = OrderDetailController(
      h.session,
      h.commerce.orders,
      h.commerce.mutations,
      AddressRepository(h.api),
      customerId,
    );
    addTearDown(c.dispose);
    await c.load();
    await c.loadAddresses();
    final selected = c.addresses.single;
    await c.correct(selected);
    expect(h.commerce.mutations.pending(customerId), isNull);
    expect(
      h.commerce.mutations.errorFor(customerId),
      contains('same location and map pin'),
    );
    expect(h.commerce.mutations.fieldErrors['address_id'], 'Check this field.');
    expect(c.stale, false);
    expect(c.order!.address.version, 1);
    expect(c.addressesFresh, false);
    await c.retryMutation();
    await c.correct(selected);
    await c.loadAddresses();
    expect(c.addresses, isEmpty);
    expect(h.adapter.requests.where((r) => r.method == 'PATCH'), hasLength(1));
  });
}
