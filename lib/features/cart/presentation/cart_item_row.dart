import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../discovery/presentation/catalog_image.dart';
import '../data/cart_models.dart';
import 'cart_line_editor.dart';

class CartItemRow extends StatelessWidget {
  const CartItemRow({
    super.key,
    required this.line,
    required this.dependencies,
  });
  final CartLine line;
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) {
    final cart = dependencies.commerce!.cart;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(line.productName, style: Theme.of(context).textTheme.titleMedium),
        if (line.options.isNotEmpty)
          Text(line.options.map((o) => '${o.group}: ${o.value}').join(', ')),
        const SizedBox(height: 8),
        Text(
          '₱${line.unitPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Quantity ${line.quantity} · ₱${line.subtotal.toStringAsFixed(2)}',
        ),
        if (!line.selectable) Text(line.availabilityLabel),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () async {
                await context.push('/products/${line.productId}');
                if (context.mounted) await cart.load();
              },
              child: const Text('View Product'),
            ),
            TextButton(
              onPressed: cart.canEdit
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => CartLineEditor(
                        dependencies: dependencies,
                        line: line,
                      ),
                    )
                  : null,
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: cart.canEdit
                  ? () async {
                      if (await confirmAction(
                        context,
                        title: 'Remove item?',
                        message: 'Remove ${line.productName} from your Cart?',
                        action: 'Remove',
                      )) {
                        await cart.remove(line.id);
                      }
                    }
                  : null,
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
    final image = dependencies.discovery == null
        ? const Icon(Icons.image_outlined, size: 64)
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CatalogImage(
              url: line.mediaUrl,
              label: line.altText.isEmpty ? line.productName : line.altText,
              discovery: dependencies.discovery!,
              width: 88,
              height: 88,
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(
                    semanticLabel: 'Select ${line.productName}',
                    value: cart.selection.contains(line.id),
                    onChanged: cart.canEdit && line.selectable
                        ? (v) => cart.select(line.id, v == true)
                        : null,
                  ),
                ),
              ),
              image,
              const SizedBox(width: 12),
              if (MediaQuery.sizeOf(context).width >= 600)
                Expanded(child: details),
            ],
          ),
          if (MediaQuery.sizeOf(context).width < 600)
            Padding(padding: const EdgeInsets.only(top: 12), child: details),
        ],
      ),
    );
  }
}
