import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShopVouchersSection extends StatelessWidget {
  const ShopVouchersSection({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.local_offer_outlined),
        title: const Text('View Shop vouchers'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('/shops/${Uri.encodeComponent(slug)}/vouchers'),
      ),
    ),
  );
}
