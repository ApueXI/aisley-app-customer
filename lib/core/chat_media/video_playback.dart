import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

abstract class ChatVideoPlayback extends ChangeNotifier {
  bool get failed => false;
  bool get playing;
  Duration get position;
  Duration get duration;
  Widget get view;
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration value);
  Future<void> close();
}

class PluginVideoPlayback extends ChatVideoPlayback {
  PluginVideoPlayback(this.controller, this.cleanup) {
    controller.addListener(_changed);
  }
  final VideoPlayerController controller;
  final Future<void> Function() cleanup;
  bool _closed = false;
  void _changed() {
    if (!_closed) notifyListeners();
  }

  @override
  bool get failed => controller.value.hasError;
  @override
  bool get playing => controller.value.isPlaying;
  @override
  Duration get position => controller.value.position;
  @override
  Duration get duration => controller.value.duration;
  @override
  Widget get view => AspectRatio(
    aspectRatio: controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9,
    child: VideoPlayer(controller),
  );
  @override
  Future<void> play() async {
    if (_closed) return;
    await controller.play();
    if (controller.value.hasError) throw StateError('Playback unavailable.');
  }

  @override
  Future<void> pause() async {
    if (!_closed) await controller.pause();
  }

  @override
  Future<void> seek(Duration value) async {
    if (!_closed) await controller.seekTo(value);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    controller.removeListener(_changed);
    try {
      await controller.dispose();
    } finally {
      await cleanup();
      super.dispose();
    }
  }
}
