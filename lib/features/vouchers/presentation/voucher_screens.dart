import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import 'voucher_list_controller.dart';
import 'voucher_list_view.dart';
import 'voucher_detail_controller.dart';
import 'voucher_card.dart';

class VoucherListScreen extends StatefulWidget {
  const VoucherListScreen({
    super.key,
    required this.dependencies,
    this.wallet = false,
  });
  final AppDependencies dependencies;
  final bool wallet;
  @override
  State<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends State<VoucherListScreen> {
  late final _controller = VoucherListController(
    widget.dependencies.session,
    widget.dependencies.vouchers!,
    widget.dependencies.voucherCollection!,
    wallet: widget.wallet,
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
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: Text(widget.wallet ? 'My Vouchers' : 'Discover vouchers'),
      actions: widget.wallet
          ? null
          : [
              if (MediaQuery.sizeOf(context).width >=
                  360 * catalogTextScale(context))
                TextButton(
                  onPressed: () => context.push('/account/vouchers'),
                  child: const Text('My Vouchers'),
                )
              else
                IconButton(
                  tooltip: 'My Vouchers',
                  onPressed: () => context.push('/account/vouchers'),
                  icon: const Icon(Icons.card_giftcard_outlined),
                ),
            ],
    ),
    body: SingleChildScrollView(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Collect offers, then select them at Checkout. Collection does not apply savings automatically.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          VoucherListView(controller: _controller),
        ],
      ),
    ),
  );
}

class VoucherDetailScreen extends StatefulWidget {
  const VoucherDetailScreen({
    super.key,
    required this.dependencies,
    required this.id,
  });
  final AppDependencies dependencies;
  final String id;
  @override
  State<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  late final _controller = VoucherDetailController(
    widget.dependencies.session,
    widget.dependencies.vouchers!,
    widget.dependencies.voucherCollection!,
    widget.id,
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
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(title: const Text('Voucher details')),
    body: SingleChildScrollView(
      padding: pagePadding(context),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_controller.loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Loading voucher details',
              ),
            if (_controller.error != null)
              Semantics(liveRegion: true, child: Text(_controller.error!)),
            if (_controller.result != null)
              VoucherCard(
                voucher: _controller.result!,
                collection: _controller.collection,
                details: true,
                allowCollect: !_controller.loading && _controller.error == null,
              ),
            TextButton(
              onPressed: _controller.loading || _controller.coolingDown
                  ? null
                  : () => _controller.load(refresh: true),
              child: const Text('Refresh voucher details'),
            ),
            if (context.canPop())
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
          ],
        ),
      ),
    ),
  );
}
