import 'dart:math';

import '../networking/api_failure.dart';
import '../networking/wire.dart';

bool validUuid(String value) =>
    RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
        .hasMatch(value);

String requireUuid(String value) {
  if (!validUuid(value)) throw const ApiFailure(FailureKind.decode);
  return value;
}

String? nullableUuid(Wire wire, String key) {
  final value = wire.nullableString(key);
  return value == null ? null : requireUuid(value);
}

DateTime requiredTime(Wire wire, String key) =>
    wire.timestamp(key) ?? (throw const ApiFailure(FailureKind.decode));

int nonnegative(Wire wire, String key) {
  final value = wire.integer(key);
  if (value < 0) throw const ApiFailure(FailureKind.decode);
  return value;
}

String secureUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Exact decimal money, also exact on JavaScript targets. No double arithmetic.
class Money {
  const Money._(this.minorUnits);
  final int minorUnits;
  factory Money.parse(Object? value) {
    if (value is! String || !RegExp(r'^\d+\.\d{2}$').hasMatch(value)) {
      throw const ApiFailure(FailureKind.decode);
    }
    final cents = BigInt.parse(value.replaceAll('.', ''));
    if (cents > BigInt.from(9007199254740991)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return Money._(cents.toInt());
  }
  String get decimal =>
      '${minorUnits ~/ 100}.${(minorUnits % 100).toString().padLeft(2, '0')}';
  String display([String currency = 'PHP']) => '$currency $decimal';
}

class CommerceTotals {
  CommerceTotals.parse(Object? json) {
    final w = Wire(json);
    merchandise = Money.parse(w.field('merchandiseSubtotal'));
    shipping = Money.parse(w.field('shippingFee'));
    discount = Money.parse(w.field('discount'));
    shippingDiscount = Money.parse(w.field('shippingDiscount'));
    payable = Money.parse(w.field('payable'));
    currency = w.string('currency');
  }
  late final Money merchandise, shipping, discount, shippingDiscount, payable;
  late final String currency;
}

class SelectedOption {
  SelectedOption.parse(Object? json) {
    final w = Wire(json);
    group = w.string('group');
    value = w.string('value');
  }
  late final String group, value;
}

class CommerceShop {
  CommerceShop.parse(Object? json, {bool order = false}) {
    final w = Wire(json);
    id = w.uuid('id');
    name = w.string('name');
    slug = order ? w.string('slug') : null;
    logoUrl = order ? w.nullableString('logoUrl') : null;
  }
  late final String id, name;
  late final String? slug, logoUrl;
}
