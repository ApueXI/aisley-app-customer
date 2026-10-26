import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'commerce_address.dart';

bool supportedShippingRoute(String status) =>
    const ['local', 'planned', 'unplanned'].contains(status);

class LogisticsOptions {
  LogisticsOptions.parse(Object? json) {
    final w = Wire(json);
    address = CommerceAddress.parse(w.object('address'), quote: true);
    groups = w.list('groups', LogisticsOptionGroup.parse);
    if (groups.isEmpty ||
        groups.map((g) => g.shop.id.toLowerCase()).toSet().length !=
            groups.length) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final CommerceAddress address;
  late final List<LogisticsOptionGroup> groups;
}

class LogisticsOptionGroup {
  LogisticsOptionGroup.parse(Object? json) {
    final w = Wire(json);
    shop = CommerceShop.parse(w.object('shop'));
    options = w.list('options', LogisticsOption.parse);
    if (options.map((o) => o.organizationId.toLowerCase()).toSet().length !=
        options.length) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final CommerceShop shop;
  late final List<LogisticsOption> options;
}

class LogisticsOption {
  LogisticsOption.parse(Object? json) {
    final w = Wire(json);
    organizationId = w.uuid('organizationId').toLowerCase();
    businessName = w.string('businessName');
    fee = Money.parse(w.field('shippingFee'));
    routeStatus = w.string('routeStatus');
  }
  late final String organizationId, businessName, routeStatus;
  late final Money fee;
  bool get supported => const ['local', 'planned'].contains(routeStatus);
}

class ShippingProvider {
  ShippingProvider.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    businessName = w.string('businessName');
  }
  late final String id, businessName;
}
