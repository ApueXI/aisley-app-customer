import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../app/app_dependencies.dart';
import '../data/product_detail_model.dart';
import 'catalog_image.dart';

class ProductInformation extends StatelessWidget {
  const ProductInformation({
    super.key,
    required this.dependencies,
    required this.product,
  });
  final AppDependencies dependencies;
  final ProductDetail product;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (product.specifications != null)
        _specifications(context, product.specifications!),
      if (product.descriptionMarkdown?.isNotEmpty == true)
        _description(context, product.descriptionMarkdown!),
    ],
  );
  Widget _specifications(BuildContext context, Object value) {
    final rows = <(String, String)>[];
    var malformed = false;
    if (value is List) {
      for (final item in value) {
        if (item is Map && item['name'] is String && item['value'] is String) {
          rows.add((item['name'] as String, item['value'] as String));
        } else {
          malformed = true;
        }
      }
    } else if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        if (entry.value is String ||
            entry.value is num ||
            entry.value is bool) {
          rows.add((entry.key, '${entry.value}'));
        } else {
          malformed = true;
        }
      }
    } else {
      malformed = true;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Specifications', style: Theme.of(context).textTheme.titleLarge),
          if (rows.isEmpty || malformed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Some specifications are unavailable.'),
            ),
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[index].$1,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: Text(rows[index].$2)),
                ],
              ),
            ),
            if (index + 1 < rows.length) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _description(BuildContext context, String markdown) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: Theme.of(context).textTheme.titleLarge),
          MarkdownBody(
            data: markdown,
            selectable: true,
            imageBuilder: (uri, title, alt) => CatalogImage(
              url: uri.toString(),
              discovery: dependencies.discovery!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.contain,
              label: alt,
            ),
            onTapLink: (text, href, title) {
              if (href != null) dependencies.launcher.open(href);
            },
          ),
        ],
      ),
    );
  }
}
