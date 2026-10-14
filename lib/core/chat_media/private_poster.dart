import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'draft_controller.dart';

class PrivateVideoPoster extends StatefulWidget {
  const PrivateVideoPoster({
    super.key,
    required this.attachment,
    required this.controller,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  @override
  State<PrivateVideoPoster> createState() => _PrivateVideoPosterState();
}

class _PrivateVideoPosterState extends State<PrivateVideoPoster> {
  ChatMediaRead? _read;
  MemoryImage? _image;
  late int _generation;
  String? _error;
  @override
  void initState() {
    super.initState();
    _generation = widget.controller.privateGeneration;
    widget.controller.addListener(_scope);
    _load();
  }

  void _reset() {
    _read?.cancel();
    _image?.evict();
    _image = null;
  }

  void _scope() {
    if (_generation != widget.controller.privateGeneration) {
      _reset();
      if (mounted) setState(() => _error = 'Video preview access ended.');
    }
  }

  @override
  void didUpdateWidget(PrivateVideoPoster old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller) ||
        old.attachment.id != widget.attachment.id ||
        old.attachment.previewUrl != widget.attachment.previewUrl) {
      old.controller.removeListener(_scope);
      _reset();
      _generation = widget.controller.privateGeneration;
      widget.controller.addListener(_scope);
      _load();
    }
  }

  Future<void> _load() async {
    if (_generation != widget.controller.privateGeneration) return;
    _reset();
    final read = ChatMediaRead();
    _read = read;
    _error = null;
    final repo = widget.controller.repository;
    try {
      if (repo is! ChatMediaContentRepository) {
        throw const ChatMediaFailure('Preview unavailable.');
      }
      final Uint8List bytes = await (repo as ChatMediaContentRepository)
          .content(widget.attachment, read, preview: true);
      if (mounted &&
          read.isCurrent &&
          _generation == widget.controller.privateGeneration) {
        setState(() => _image = MemoryImage(bytes));
      }
    } catch (_) {
      if (mounted && read.isCurrent) {
        setState(() => _error = 'Video preview unavailable.');
      }
    }
  }

  @override
  void dispose() {
    _reset();
    widget.controller.removeListener(_scope);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image != null
      ? Image(
          image: _image!,
          width: 220,
          height: 124,
          fit: BoxFit.contain,
          semanticLabel: 'Video preview',
          errorBuilder: (_, error, stack) =>
              const Text('Video preview unavailable.'),
        )
      : Text(_error ?? 'Loading video preview…');
}
