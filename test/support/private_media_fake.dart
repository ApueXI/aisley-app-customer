import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/content_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/media_platform.dart';
import 'package:aisley_mobile_buyer/core/chat_media/video_playback.dart';

import 'chat_media_fake.dart';

class ContentFake extends MediaFake implements ChatMediaContentRepository {
  final reads = <ChatMediaRead>[];
  final contentIds = <String>[];
  Completer<Uint8List>? delayedContent;
  ChatMediaFailure? failure;
  @override
  Future<Uint8List> content(
    ChatAttachment attachment,
    ChatMediaRead read, {
    bool preview = false,
  }) async {
    if (preview) return image('preview');
    contentIds.add(attachment.id);
    reads.add(read);
    if (failure != null) throw failure!;
    return delayedContent?.future ?? Uint8List(attachment.byteSize);
  }
}

class PlaybackFake extends ChatVideoPlayback {
  bool _playing = false, closed = false, fail = false;
  int playCalls = 0;
  Duration at = Duration.zero;
  @override
  bool get playing => _playing;
  @override
  Duration get position => at;
  @override
  Duration get duration => const Duration(seconds: 10);
  @override
  Widget get view =>
      const SizedBox(height: 100, child: Text('Synthetic video frame'));
  @override
  Future<void> play() async {
    if (fail) throw StateError('Failed');
    playCalls++;
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    if (!closed) notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    at = value;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      super.dispose();
    }
  }
}

class PlatformFake implements ChatMediaPlatform {
  int saves = 0, prepares = 0;
  bool saveResult = true;
  ChatMediaRead? saveRead;
  PlaybackFake player = PlaybackFake();
  Completer<bool>? delayedSave;
  @override
  Future<ChatVideoPlayback> video(Uint8List bytes, ChatMediaRead read) async {
    prepares++;
    return player;
  }

  @override
  Future<bool> save(
    Uint8List bytes,
    ChatAttachment attachment,
    ChatMediaRead read,
  ) async {
    saves++;
    saveRead = read;
    return delayedSave?.future ?? saveResult;
  }
}

ChatAttachment receivedFile({
  String id = assetId,
  String kind = 'document',
  int size = 3,
  String? filename,
  String? mime,
  String state = 'ready',
}) => ChatAttachment(
  id: id,
  kind: kind,
  state: state,
  byteSize: size,
  filename: filename ?? (kind == 'video' ? 'visit.mp4' : 'instructions.pdf'),
  mimeType: mime ?? (kind == 'video' ? 'video/mp4' : 'application/pdf'),
  previewUrl: '/api/v1/customer/chat-attachments/$id/preview',
  contentUrl: '/api/v1/customer/chat-attachments/$id/content',
);
