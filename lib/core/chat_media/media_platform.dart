import 'dart:typed_data';

import 'attachment.dart';
import 'content_repository.dart';
import 'video_playback.dart';
import 'media_platform_stub.dart'
    if (dart.library.io) 'media_platform_native.dart'
    if (dart.library.js_interop) 'media_platform_web.dart'
    as platform;

abstract interface class ChatMediaPlatform {
  Future<ChatVideoPlayback> video(Uint8List bytes, ChatMediaRead read);
  Future<bool> save(
    Uint8List bytes,
    ChatAttachment attachment,
    ChatMediaRead read,
  );
}

final ChatMediaPlatform privateMediaPlatform = platform.createMediaPlatform();
Future<void> cleanAbandonedChatMedia() => platform.cleanAbandonedChatMedia();
