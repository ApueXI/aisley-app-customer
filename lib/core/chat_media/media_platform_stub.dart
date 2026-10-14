import 'dart:typed_data';

import 'attachment.dart';
import 'content_repository.dart';
import 'media_platform.dart';
import 'video_playback.dart';

ChatMediaPlatform createMediaPlatform() => _Unavailable();
Future<void> cleanAbandonedChatMedia() async {}

class _Unavailable implements ChatMediaPlatform {
  @override
  Future<ChatVideoPlayback> video(Uint8List bytes, ChatMediaRead read) async =>
      throw const ChatMediaFailure(
        'Video playback is unavailable on this device.',
      );
  @override
  Future<bool> save(
    Uint8List bytes,
    ChatAttachment attachment,
    ChatMediaRead read,
  ) async => throw const ChatMediaFailure(
    'Document downloads are unavailable on this device.',
  );
}
