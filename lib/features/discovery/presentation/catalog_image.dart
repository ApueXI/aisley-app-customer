import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/networking/api_client.dart';
import '../data/discovery_repository.dart';

class CatalogImage extends StatefulWidget {
  const CatalogImage({
    super.key,
    required this.url,
    required this.discovery,
    this.lease,
    this.width,
    this.height,
    this.label,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final DiscoveryRepository discovery;
  final SessionLease? lease;
  final double? width, height;
  final String? label;
  final BoxFit fit;

  @override
  State<CatalogImage> createState() => _CatalogImageState();
}

class _CatalogImageState extends State<CatalogImage> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CatalogImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.lease != widget.lease) _load();
  }

  void _load() {
    final url = widget.url;
    _image = url == null || url.isEmpty
        ? null
        : Future<Uint8List>.sync(
            () => widget.lease == null
                ? widget.discovery.publicMedia(url)
                : widget.discovery.privateMedia(url, widget.lease!),
          );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: _image == null
        ? _fallback(context)
        : FutureBuilder<Uint8List>(
            key: ObjectKey(_image),
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(
                  snapshot.data!,
                  fit: widget.fit,
                  semanticLabel: widget.label,
                  errorBuilder: (_, _, _) => _fallback(context),
                );
              }
              if (snapshot.hasError) return _fallback(context);
              return const ColoredBox(
                color: Color(0xFFF4F0F3),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
  );

  Widget _fallback(BuildContext context) => ColoredBox(
    color: const Color(0xFFF4F0F3),
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Theme.of(context).colorScheme.secondary,
        semanticLabel: widget.label ?? 'Image unavailable',
      ),
    ),
  );
}
