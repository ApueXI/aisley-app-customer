import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/marketplace_widgets.dart';
import 'voucher_list_controller.dart';
import 'voucher_list_view.dart';

class ShopVouchersSection extends StatefulWidget {
  const ShopVouchersSection({
    super.key,
    required this.dependencies,
    required this.slug,
  });
  final AppDependencies dependencies;
  final String slug;
  @override
  State<ShopVouchersSection> createState() => _ShopVouchersSectionState();
}

class _ShopVouchersSectionState extends State<ShopVouchersSection> {
  late final _controller = VoucherListController(
    widget.dependencies.session,
    widget.dependencies.vouchers!,
    widget.dependencies.voucherCollection!,
    shopSlug: widget.slug,
  );
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: MarketSection(
      title: 'Shop vouchers',
      child: VoucherListView(controller: _controller),
    ),
  );
}
