import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'attachment.dart';
import 'draft_controller.dart';

class PrivateChatImage extends StatefulWidget {
  const PrivateChatImage({
    super.key,
    required this.attachment,
    required this.controller,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  @override
  State<PrivateChatImage> createState() => _PrivateChatImageState();
}

class _PrivateChatImageState extends State<PrivateChatImage> {
  Uint8List? _bytes;
  MemoryImage? _provider;
  String? _error;
  bool _loading = false;
  int _request = 0;
  late int _generation;
  @override
  void initState() {
    super.initState();
    _generation = widget.controller.privateGeneration;
    widget.controller.addListener(_scopeChanged);
    if (widget.attachment.kind == 'image') _load();
  }

  void _scopeChanged() {
    if (widget.controller.privateGeneration != _generation) {
      _request++;
      _bytes = null;
      _loading = false;
      _error = 'Image access ended.';
      _provider?.evict();
      _provider = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    if (_generation != widget.controller.privateGeneration) return;
    final stamp = widget.controller.privateGeneration, request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = widget.attachment.previewUrl;
      if (url == null) throw const ChatMediaFailure('Image unavailable.');
      final bytes = await widget.controller.repository.image(url);
      if (!mounted ||
          request != _request ||
          stamp != widget.controller.privateGeneration) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _provider = MemoryImage(bytes);
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Image unavailable. Retry when connected.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _view() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PrivateImageViewer(
        attachment: widget.attachment,
        controller: widget.controller,
      ),
    );
  }

  @override
  void dispose() {
    _request++;
    widget.controller.removeListener(_scopeChanged);
    _provider?.evict();
    _bytes = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.kind != 'image') {
      return Text(
        '${widget.attachment.filename} · ${widget.attachment.kind}. Viewing this format is not supported yet.',
      );
    }
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _bytes == null) {
      return Column(
        children: [
          Text(_error ?? 'Image unavailable.'),
          if (_generation == widget.controller.privateGeneration)
            TextButton(onPressed: _load, child: const Text('Retry image')),
        ],
      );
    }
    return Semantics(
      label: 'View ${widget.attachment.filename}',
      button: true,
      child: InkWell(
        onTap: _view,
        child: Image(
          image: _provider!,
          width: 220,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) =>
              const Text('This image cannot be displayed.'),
        ),
      ),
    );
  }
}

class _PrivateImageViewer extends StatefulWidget {
  const _PrivateImageViewer({
    required this.attachment,
    required this.controller,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  @override
  State<_PrivateImageViewer> createState() => _PrivateImageViewerState();
}

class _PrivateImageViewerState extends State<_PrivateImageViewer> {
  MemoryImage? _image;
  String? _error;
  late final int _generation = widget.controller.privateGeneration;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_clear);
    _load();
  }

  void _clear() {
    if (widget.controller.privateGeneration != _generation) {
      _image?.evict();
      _image = null;
      if (mounted) setState(() => _error = 'Image access ended.');
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final url = widget.attachment.contentUrl;
      if (url == null) throw const ChatMediaFailure('Image unavailable.');
      final bytes = await widget.controller.repository.image(url);
      if (mounted && _generation == widget.controller.privateGeneration) {
        setState(() => _image = MemoryImage(bytes));
      }
    } catch (_) {
      if (mounted && _generation == widget.controller.privateGeneration) {
        setState(() => _error = 'Image unavailable.');
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_clear);
    _image?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.attachment.filename),
    content: SizedBox(
      width: 600,
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: _error != null
          ? Text(_error!)
          : _image == null
          ? const Center(child: CircularProgressIndicator())
          : InteractiveViewer(
              child: Image(
                image: _image!,
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) =>
                    const Text('This image cannot be displayed.'),
              ),
            ),
    ),
    actions: [
      if (_error != null && _generation == widget.controller.privateGeneration)
        TextButton(onPressed: _load, child: const Text('Retry')),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
