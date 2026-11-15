import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';

class OrderPreparation {
  OrderPreparation.parse(Object? json) {
    final w = Wire(json);
    acceptedAt = optionalTime(w, 'acceptedAt');
    deadlineAt = optionalTime(w, 'deadlineAt');
    extendedAt = optionalTime(w, 'extendedAt');
    serverTime = requiredTime(w, 'serverTime');
    extensionUsed = w.boolean('extensionUsed');
    overdue = w.boolean('overdue');
    active = w.boolean('active');
  }
  late final DateTime? acceptedAt, deadlineAt, extendedAt;
  late final DateTime serverTime;
  late final bool extensionUsed, overdue, active;

  static DateTime? optionalTime(Wire w, String key) =>
      w.field(key) == null ? null : requiredTime(w, key);
}
