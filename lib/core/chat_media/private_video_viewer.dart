import 'dart:async';

import 'package:flutter/material.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'draft_controller.dart';
import 'media_platform.dart';
import 'media_cooldown.dart';
import 'video_playback.dart';

class PrivateVideoViewer extends StatefulWidget {
  const PrivateVideoViewer({
    super.key,
    required this.attachment,
    required this.controller,
    required this.read,
    required this.platform,
  });
  final ChatAttachment attachment;
  final ChatMediaDraftController controller;
  final ChatMediaRead read;
  final ChatMediaPlatform platform;
  @override
  State<PrivateVideoViewer> createState() => _PrivateVideoViewerState();
}

class _PrivateVideoViewerState extends State<PrivateVideoViewer>
    with WidgetsBindingObserver {
  ChatVideoPlayback? _player;
  late final _cooldown = MediaCooldown(() {
    if (mounted) setState(() {});
  });
  ChatMediaRead? _attempt;
  String? _error;
  late final int _generation = widget.controller.privateGeneration;
  bool get _current =>
      mounted &&
      widget.read.isCurrent &&
      _generation == widget.controller.privateGeneration;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scope);
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      widget.read.cancelled.then((_) {
        _release();
        if (mounted) setState(() => _error = 'Video access ended.');
      }),
    );
    _load();
  }

  void _release() {
    _attempt?.cancel();
    _attempt = null;
    final player = _player;
    _player = null;
    player?.removeListener(_changed);
    if (player != null) unawaited(player.close().catchError((_) {}));
  }

  void _scope() {
    if (_generation != widget.controller.privateGeneration) {
      widget.read.cancel();
      _release();
      if (mounted) setState(() => _error = 'Video access ended.');
    }
  }

  void _changed() {
    if (_current) {
      if (_player?.failed == true) {
        _release();
        _error = 'Playback failed. Retry the video.';
      }
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_player?.pause().catchError((_) {}) ?? Future<void>.value());
    }
  }

  Future<void> _load() async {
    if (!_current || _cooldown.active) return;
    _release();
    final attempt = ChatMediaRead();
    _attempt = attempt;
    unawaited(widget.read.cancelled.then((_) => attempt.cancel()));
    setState(() => _error = null);
    ChatVideoPlayback? player;
    try {
      final repository = widget.controller.repository;
      if (repository is! ChatMediaContentRepository) {
        throw const ChatMediaFailure('Video unavailable.');
      }
      final bytes = await (repository as ChatMediaContentRepository).content(
        widget.attachment,
        attempt,
      );
      if (!_current || !attempt.isCurrent) return;
      player = await widget.platform.video(bytes, attempt);
      if (!_current || !attempt.isCurrent) {
        await player.close();
        return;
      }
      _player = player;
      player.addListener(_changed);
      setState(() {});
    } on ChatMediaFailure catch (failure) {
      await player?.close();
      if (_current && attempt.isCurrent) {
        _cooldown.failure(failure);
        setState(
          () => _error = failure.status == 429
              ? 'Too many requests. Wait before retrying the video.'
              : 'Video unavailable. Retry when connected.',
        );
      }
    } catch (_) {
      await player?.close();
      if (_current && attempt.isCurrent) {
        setState(() => _error = 'Video unavailable. Retry when connected.');
      }
    }
  }

  Future<void> _action(Future<void> Function(ChatVideoPlayback) action) async {
    final player = _player;
    if (!_current || player == null) return;
    try {
      await action(player);
    } catch (_) {
      _release();
      if (_current) {
        setState(() => _error = 'Playback failed. Retry the video.');
      }
    }
  }

  @override
  void dispose() {
    widget.read.cancel();
    _cooldown.dispose();
    _release();
    widget.controller.removeListener(_scope);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _player;
    return AlertDialog(
      title: Text(widget.attachment.filename),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .55,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!))
              else if (p == null)
                const CircularProgressIndicator(semanticsLabel: 'Loading video')
              else ...[
                p.view,
                Text(
                  '${p.position.inSeconds} / ${p.duration.inSeconds} seconds',
                ),
                Slider(
                  value: p.position.inMilliseconds.toDouble().clamp(
                    0,
                    p.duration.inMilliseconds.toDouble(),
                  ),
                  max: p.duration.inMilliseconds > 0
                      ? p.duration.inMilliseconds.toDouble()
                      : 1,
                  semanticFormatterCallback: (value) =>
                      '${(value / 1000).round()} seconds',
                  onChanged: _current
                      ? (v) => _action(
                          (p) => p.seek(Duration(milliseconds: v.round())),
                        )
                      : null,
                ),
                TextButton.icon(
                  onPressed: _current
                      ? () => _action((p) => p.playing ? p.pause() : p.play())
                      : null,
                  icon: Icon(p.playing ? Icons.pause : Icons.play_arrow),
                  label: Text(p.playing ? 'Pause' : 'Play'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_error != null && _current)
          TextButton(
            onPressed: _cooldown.active ? null : _load,
            child: const Text('Retry video'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
