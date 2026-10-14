import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'media_platform.dart';
import 'video_playback.dart';

const _channel = MethodChannel('aisley/private_chat_documents');
Future<Directory> _root() async =>
    Directory('${(await getTemporaryDirectory()).path}/aisley-chat-playback');
Future<void> cleanAbandonedChatMedia() async {
  try {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  } catch (_) {
    /* Best effort only; no filenames or private paths are logged. */
  }
}

ChatMediaPlatform createMediaPlatform() => NativeChatMediaPlatform();

class NativeChatMediaPlatform implements ChatMediaPlatform {
  NativeChatMediaPlatform({bool? isAndroid})
    : _android = isAndroid ?? Platform.isAndroid;
  final bool _android;
  bool _saving = false;
  @override
  Future<ChatVideoPlayback> video(Uint8List bytes, ChatMediaRead read) async {
    final root = await _root();
    if (!read.isCurrent) throw const ChatMediaFailure('Video access ended.');
    await root.create(recursive: true);
    final dir = await root.createTemp('view-');
    VideoPlayerController? controller;
    var released = false;
    Future<void> cleanup() async {
      if (released) return;
      released = true;
      await controller?.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }

    unawaited(read.cancelled.then((_) => cleanup()).catchError((_) {}));
    try {
      final file = File('${dir.path}/video.mp4');
      await file.writeAsBytes(bytes, flush: true);
      if (!read.isCurrent) throw const ChatMediaFailure('Video access ended.');
      controller = VideoPlayerController.file(file);
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!read.isCurrent || controller.value.hasError) {
        throw const ChatMediaFailure('Video unavailable.');
      }
      return PluginVideoPlayback(controller, () async {
        released = true;
        if (await dir.exists()) await dir.delete(recursive: true);
      });
    } catch (_) {
      await cleanup();
      rethrow;
    }
  }

  @override
  Future<bool> save(
    Uint8List bytes,
    ChatAttachment attachment,
    ChatMediaRead read,
  ) async {
    historicalMediaLimit(attachment);
    if (!_android) {
      throw const ChatMediaFailure(
        'Document download is available on Android.',
      );
    }
    if (_saving || !read.isCurrent) return false;
    _saving = true;
    final name = attachment.filename;
    String? id;
    var finished = false;
    // The picker holds no bytes. Scope loss invalidates its result before writing.
    unawaited(
      read.cancelled
          .then((_) async {
            if (!finished) await _channel.invokeMethod<void>('cancel');
          })
          .catchError((_) {}),
    );
    try {
      id = await _channel.invokeMethod<String>('choose', {
        'filename': name,
        'mimeType': attachment.mimeType,
      });
      if (id == null || !read.isCurrent) return false;
      await _channel.invokeMethod<void>('write', {'id': id, 'bytes': bytes});
      return read.isCurrent;
    } finally {
      finished = true;
      try {
        await _channel.invokeMethod<void>('release', {'id': id});
      } finally {
        _saving = false;
      }
    }
  }
}
