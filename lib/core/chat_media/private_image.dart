import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'attachment.dart';
import 'private_file.dart';
import 'private_image_viewer.dart';
import 'content_repository.dart';
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
  ChatMediaRead? _read;
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

  @override
  void didUpdateWidget(PrivateChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = !identical(
      oldWidget.controller,
      widget.controller,
    );
    final oldAttachment = oldWidget.attachment;
    final attachment = widget.attachment;
    final attachmentChanged =
        oldAttachment.id != attachment.id ||
        oldAttachment.kind != attachment.kind ||
        oldAttachment.state != attachment.state ||
        oldAttachment.previewUrl != attachment.previewUrl;
    if (!controllerChanged && !attachmentChanged) return;

    if (controllerChanged) {
      oldWidget.controller.removeListener(_scopeChanged);
      _generation = widget.controller.privateGeneration;
      widget.controller.addListener(_scopeChanged);
    }
    _resetImage();
    if (_generation != widget.controller.privateGeneration) {
      _error = 'Image access ended.';
    } else if (attachment.kind == 'image') {
      _load();
    }
  }

  void _resetImage() {
    _request++;
    _read?.cancel();
    _read = null;
    _bytes = null;
    _loading = false;
    _error = null;
    _provider?.evict();
    _provider = null;
  }

  void _scopeChanged() {
    if (widget.controller.privateGeneration != _generation) {
      _resetImage();
      _error = 'Image access ended.';
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    final controller = widget.controller;
    if (_generation != controller.privateGeneration) return;
    final attachment = widget.attachment;
    _resetImage();
    final stamp = _generation, request = _request;
    bool current() =>
        mounted &&
        request == _request &&
        identical(controller, widget.controller) &&
        stamp == controller.privateGeneration;
    setState(() {
      _loading = true;
    });
    try {
      final url = attachment.previewUrl;
      if (url == null) throw const ChatMediaFailure('Image unavailable.');
      final read = ChatMediaRead();
      _read = read;
      final repo = controller.repository;
      final bytes = repo is ChatMediaContentRepository
          ? await (repo as ChatMediaContentRepository).content(
              attachment,
              read,
              preview: true,
            )
          : await repo.image(url);
      if (!current()) return;
      setState(() {
        _bytes = bytes;
        _provider = MemoryImage(bytes);
      });
    } catch (_) {
      if (current()) {
        setState(() => _error = 'Image unavailable. Retry when connected.');
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _view() async {
    if (_generation != widget.controller.privateGeneration || _bytes == null) {
      return;
    }
    final attachment = widget.attachment;
    final controller = widget.controller;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          PrivateImageViewer(attachment: attachment, controller: controller),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scopeChanged);
    _resetImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.kind != 'image') {
      return PrivateChatFile(
        attachment: widget.attachment,
        controller: widget.controller,
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
