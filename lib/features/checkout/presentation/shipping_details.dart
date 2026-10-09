import 'package:flutter/material.dart';

import '../data/shipping_models.dart';

String? shippingRouteMessage(String status) => status == 'unplanned'
    ? 'Shipping is quoted. The delivery route is not confirmed; no delivery time is available.'
    : supportedShippingRoute(status)
    ? null
    : 'Shipping route information is unavailable.';

/// Read-only server facts shared by checkout and Order presentation.
class ShippingDetails extends StatelessWidget {
  const ShippingDetails({
    super.key,
    required this.businessName,
    required this.fee,
    this.routeStatus,
  });
  final String? businessName, routeStatus;
  final String fee;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        businessName == null
            ? 'Shipping provider unavailable'
            : 'Shipping provider: $businessName',
      ),
      Text('Shipping fee: $fee'),
      if (routeStatus != null && shippingRouteMessage(routeStatus!) != null)
        Text(shippingRouteMessage(routeStatus!)!),
    ],
  );
}
