import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/responsive_layout.dart';
import 'voucher_card.dart';
import 'voucher_list_controller.dart';

/// Shop discovery, global discovery and wallet lists share cards and paging.
class VoucherListView extends StatelessWidget {
  const VoucherListView({
    super.key,
    required this.controller,
    this.filters = true,
  });
  final VoucherListController controller;
  final bool filters;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final result = c.result;
      final busy = c.loading || c.coolingDown;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.wallet)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'available': 'Available',
                  'upcoming': 'Upcoming',
                  'history': 'History',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: c.status == entry.key,
                    onSelected: c.coolingDown
                        ? null
                        : (_) => c.filters(
                            issuer: c.issuer,
                            benefit: c.benefit,
                            status: entry.key,
                          ),
                  ),
              ],
            ),
          if (filters)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.shopSlug == null)
                  for (final entry in const {
                    '': 'All issuers',
                    'app': 'Aisley',
                    'shop': 'Shops',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: (c.issuer ?? '') == entry.key,
                      onSelected: c.coolingDown
                          ? null
                          : (_) => c.filters(
                              issuer: entry.key.isEmpty ? null : entry.key,
                              benefit: c.benefit,
                            ),
                    ),
                for (final entry in const {
                  '': 'All benefits',
                  'discount': 'Discount',
                  'shipping': 'Shipping',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: (c.benefit ?? '') == entry.key,
                    onSelected: c.coolingDown
                        ? null
                        : (_) => c.filters(
                            issuer: c.issuer,
                            benefit: entry.key.isEmpty ? null : entry.key,
                          ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (c.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading vouchers'),
          if (c.error != null)
            Semantics(liveRegion: true, child: Text(c.error!)),
          if (c.statusError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                'Your voucher availability could not be checked. ${c.statusError}',
              ),
            ),
          if (c.stale && result != null)
            const Text(
              'Showing the last successful page. Refresh before collecting.',
            ),
          if (result != null) ...[
            if (result.items.isEmpty)
              Text(
                c.page > result.pagination.lastPage
                    ? 'This page has no vouchers. Return to the first page.'
                    : c.wallet
                    ? 'No vouchers in this tab. Discover offers to collect.'
                    : 'No vouchers match these filters.',
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = 320 * catalogTextScale(context);
                final columns = ((constraints.maxWidth + 12) / (minWidth + 12))
                    .floor()
                    .clamp(1, 3);
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  children: [
                    for (final v in result.items)
                      SizedBox(
                        width: width,
                        child: VoucherCard(
                          voucher: v,
                          collection: c.collection,
                          overlay: !c.wallet,
                          allowCollect:
                              !busy && !c.stale && c.statusError == null,
                        ),
                      ),
                  ],
                );
              },
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: !busy && result.pagination.currentPage > 1
                      ? () => c.setPage(result.pagination.currentPage - 1)
                      : null,
                  child: const Text('Previous vouchers'),
                ),
                Text(
                  'Voucher page ${result.pagination.currentPage} of ${result.pagination.lastPage}',
                ),
                TextButton(
                  onPressed: !busy && result.pagination.hasNext
                      ? () => c.setPage(result.pagination.currentPage + 1)
                      : null,
                  child: const Text('Next vouchers'),
                ),
                if (c.page > result.pagination.lastPage)
                  TextButton(
                    onPressed: busy ? null : () => c.setPage(1),
                    child: const Text('First voucher page'),
                  ),
              ],
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => c.load(refresh: true),
                child: Text(
                  c.error != null || c.statusError != null
                      ? 'Retry vouchers'
                      : 'Refresh vouchers',
                ),
              ),
              if (c.wallet)
                TextButton(
                  onPressed: () => context.push('/vouchers'),
                  child: const Text('Discover vouchers'),
                ),
            ],
          ),
        ],
      );
    },
  );
}
