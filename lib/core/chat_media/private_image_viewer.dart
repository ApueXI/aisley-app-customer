import 'package:flutter/material.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'draft_controller.dart';

class PrivateImageViewer extends StatefulWidget {
  const PrivateImageViewer({
    super.key,
    required this.attachment,
    required this.controller,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  @override
  State<PrivateImageViewer> createState() => PrivateImageViewerState();
}

class PrivateImageViewerState extends State<PrivateImageViewer> {
  ChatMediaRead? _read;
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
      _read?.cancel();
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
      _read?.cancel();
      final read = ChatMediaRead();
      _read = read;
      final repo = widget.controller.repository;
      final bytes = repo is ChatMediaContentRepository
          ? await (repo as ChatMediaContentRepository).content(
              widget.attachment,
              read,
            )
          : await repo.image(url);
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
    _read?.cancel();
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
