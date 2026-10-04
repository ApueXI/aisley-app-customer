import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../discovery/presentation/product_controller.dart';
import '../data/cart_models.dart';

class CartLineEditor extends StatefulWidget {
  const CartLineEditor({
    super.key,
    required this.dependencies,
    required this.line,
  });
  final AppDependencies dependencies;
  final CartLine line;
  @override
  State<CartLineEditor> createState() => _CartLineEditorState();
}

class _CartLineEditorState extends State<CartLineEditor> {
  late final _product = ProductDetailController(
    widget.dependencies.discovery!,
    widget.line.productId,
  );
  late final _quantity = TextEditingController(text: '${widget.line.quantity}');
  final _form = GlobalKey<FormState>();
  String? _variant;
  bool _changeVariant = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _product.load();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _product.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _product,
    builder: (context, _) => AlertDialog(
      title: Text('Edit ${widget.line.productName}'),
      scrollable: true,
      content: Form(
        key: _form,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                enabled: !_saving,
                validator: (text) {
                  final value = int.tryParse(text ?? '');
                  return value == null || value < 1 || value > 2147483647
                      ? 'Enter a positive whole quantity.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              if (_product.loading) const LinearProgressIndicator(),
              if (_product.error != null) Text(_product.error!),
              if (_product.product?.availability.requiresVariantSelection ==
                  true)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Replace variant (optional)',
                  ),
                  items: [
                    for (final variant in _product.product!.variants)
                      DropdownMenuItem(
                        value: variant.id,
                        enabled: variant.inStock,
                        child: Text(_variantLabel(variant.optionValueIds)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _variant = value;
                          _changeVariant = true;
                        }),
                ),
              if (!_product.loading &&
                  _product.product?.availability.requiresVariantSelection ==
                      false &&
                  widget.line.variantId != null)
                CheckboxListTile(
                  title: const Text('Use base Product configuration'),
                  value: _changeVariant,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _variant = null;
                          _changeVariant = value == true;
                        }),
                ),
              if (widget.dependencies.commerce!.cart.error != null)
                Text(widget.dependencies.commerce!.cart.error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
  String _variantLabel(List<String> ids) => [
    for (final group in _product.product!.optionGroups)
      for (final value in group.values)
        if (ids.contains(value.id)) '${group.name}: ${value.value}',
  ].join(', ');
  Future<void> _save() async {
    if (!validateForm(_form.currentState!)) return;
    setState(() => _saving = true);
    final success = await widget.dependencies.commerce!.cart.update(
      widget.line.id,
      quantity: int.parse(_quantity.text),
      variantId: _variant,
      changeVariant: _changeVariant,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }
}
