import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'draft_controller.dart';
import 'media_platform.dart';
import 'media_cooldown.dart';
import 'private_video_viewer.dart';
import 'private_poster.dart';

class PrivateChatFile extends StatefulWidget {
  const PrivateChatFile({
    super.key,
    required this.attachment,
    required this.controller,
    this.platform,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  final ChatMediaPlatform? platform;
  @override
  State<PrivateChatFile> createState() => _PrivateChatFileState();
}

class _PrivateChatFileState extends State<PrivateChatFile> {
  ChatMediaRead? _read;
  late final _cooldown = MediaCooldown(() {
    if (mounted) setState(() {});
  });
  int _generation = 0;
  bool _busy = false;
  String? _notice;
  bool get _allowed => _generation == widget.controller.privateGeneration;
  @override
  void initState() {
    super.initState();
    _generation = widget.controller.privateGeneration;
    widget.controller.addListener(_scope);
  }

  @override
  void didUpdateWidget(PrivateChatFile old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller) ||
        old.attachment.id != widget.attachment.id ||
        old.attachment.kind != widget.attachment.kind ||
        old.attachment.state != widget.attachment.state ||
        old.attachment.contentUrl != widget.attachment.contentUrl ||
        old.attachment.mimeType != widget.attachment.mimeType ||
        old.attachment.byteSize != widget.attachment.byteSize) {
      _read?.cancel();
      _read = null;
      _busy = false;
      _notice = null;
      if (!identical(old.controller, widget.controller)) {
        old.controller.removeListener(_scope);
        _generation = widget.controller.privateGeneration;
        widget.controller.addListener(_scope);
      }
    }
  }

  void _scope() {
    if (!_allowed) {
      _read?.cancel();
      _busy = false;
      if (mounted) setState(() => _notice = 'Attachment access ended.');
    }
  }

  Future<void> _download() async {
    if (_busy || !_allowed || _cooldown.active) return;
    final repository = widget.controller.repository;
    if (repository is! ChatMediaContentRepository) return;
    final read = ChatMediaRead();
    _read = read;
    Uint8List? buffered;
    unawaited(
      read.cancelled.then((_) => buffered?.fillRange(0, buffered.length, 0)),
    );
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final bytes = await (repository as ChatMediaContentRepository).content(
        widget.attachment,
        read,
      );
      buffered = bytes;
      if (!mounted || !read.isCurrent || !_allowed) return;
      final saved = await (widget.platform ?? privateMediaPlatform).save(
        bytes,
        widget.attachment,
        read,
      );
      if (mounted && read.isCurrent && _allowed) {
        setState(
          () => _notice = saved
              ? 'Download requested. Check your saved files.'
              : 'Download cancelled.',
        );
      }
    } on ChatMediaFailure catch (failure) {
      if (mounted && read.isCurrent && _allowed) {
        _cooldown.failure(failure);
        setState(
          () => _notice = failure.status == 429
              ? 'Too many requests. Wait before downloading again.'
              : 'Document unavailable. Retry when connected.',
        );
      }
    } catch (_) {
      if (mounted && read.isCurrent && _allowed) {
        setState(() => _notice = 'Document unavailable. Retry when connected.');
      }
    } finally {
      buffered?.fillRange(0, buffered.length, 0);
      buffered = null;
      read.cancel();
      if (mounted && identical(read, _read)) setState(() => _busy = false);
    }
  }

  Future<void> _video() async {
    if (!_allowed) return;
    final read = ChatMediaRead();
    _read = read;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => PrivateVideoViewer(
          attachment: widget.attachment,
          controller: widget.controller,
          read: read,
          platform: widget.platform ?? privateMediaPlatform,
        ),
      );
    } finally {
      read.cancel();
    }
  }

  @override
  void dispose() {
    _read?.cancel();
    _cooldown.dispose();
    widget.controller.removeListener(_scope);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var supported = widget.controller.repository is ChatMediaContentRepository;
    try {
      historicalMediaLimit(widget.attachment);
    } catch (_) {
      supported = false;
    }
    final a = widget.attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supported && _allowed && a.kind == 'video')
          PrivateVideoPoster(attachment: a, controller: widget.controller),
        Text(a.filename),
        Text(
          '${a.filename.split('.').last.toUpperCase()} · ${(a.byteSize / 1024).ceil()} KB',
        ),
        if (!supported)
          const Text('This attachment is unavailable or unsupported.'),
        if (_notice != null) Semantics(liveRegion: true, child: Text(_notice!)),
        if (_busy)
          const LinearProgressIndicator(semanticsLabel: 'Downloading document'),
        if (supported && _allowed)
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _busy || _cooldown.active
                ? null
                : a.kind == 'video'
                ? _video
                : _download,
            icon: Icon(a.kind == 'video' ? Icons.play_arrow : Icons.download),
            label: Text(
              _busy
                  ? 'Downloading…'
                  : a.kind == 'video'
                  ? 'View video'
                  : 'Download',
            ),
          ),
        if (a.kind == 'document')
          const Text('Downloading saves a copy on your device.'),
        if (_busy)
          TextButton(
            onPressed: () {
              _read?.cancel();
              setState(() {
                _busy = false;
                _notice = 'Download cancelled.';
              });
            },
            child: const Text('Cancel download'),
          ),
      ],
    );
  }
}
