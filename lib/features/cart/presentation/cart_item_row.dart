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
    final imageSize = MediaQuery.sizeOf(context).width < 380 ? 72.0 : 88.0;
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
              width: imageSize,
              height: imageSize,
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  semanticLabel: 'Select ${line.productName}',
                  value: cart.selection.contains(line.id),
                  onChanged: cart.canEdit && line.selectable
                      ? (value) => cart.select(line.id, value == true)
                      : null,
                ),
              ),
              IconButton(
                tooltip: 'View Product',
                onPressed: () async {
                  await context.push('/products/${line.productId}');
                  if (context.mounted) await cart.load();
                },
                icon: const Icon(Icons.open_in_new),
              ),
              IconButton(
                tooltip: 'Edit Cart item',
                color: Theme.of(context).colorScheme.primary,
                onPressed: cart.canEdit
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => CartLineEditor(
                          dependencies: dependencies,
                          line: line,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remove Cart item',
                color: Theme.of(context).colorScheme.error,
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
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(width: 8),
          image,
          const SizedBox(width: 12),
          Expanded(child: details),
        ],
      ),
    );
  }
}
