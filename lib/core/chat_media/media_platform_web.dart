import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:video_player/video_player.dart';

import 'attachment.dart';
import 'content_repository.dart';
import 'media_platform.dart';
import 'video_playback.dart';

ChatMediaPlatform createMediaPlatform() => _Browser();
Future<void> cleanAbandonedChatMedia() async {}

class _Browser implements ChatMediaPlatform {
  String _blob(Uint8List bytes, String type) => web.URL.createObjectURL(
    web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type)),
  );
  @override
  Future<ChatVideoPlayback> video(Uint8List bytes, ChatMediaRead read) async {
    if (!read.isCurrent) throw const ChatMediaFailure('Video access ended.');
    final url = _blob(bytes, 'video/mp4');
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    var released = false;
    void revoke() {
      if (!released) {
        released = true;
        web.URL.revokeObjectURL(url);
      }
    }

    unawaited(read.cancelled.then((_) => revoke()));
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!read.isCurrent || controller.value.hasError) {
        throw const ChatMediaFailure('Video unavailable.');
      }
      return PluginVideoPlayback(controller, () async => revoke());
    } catch (_) {
      await controller.dispose();
      revoke();
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
    if (!read.isCurrent) return false;
    final url = _blob(bytes, attachment.mimeType);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = attachment.filename;
    anchor.style.display = 'none';
    try {
      web.document.body?.appendChild(anchor);
      if (!read.isCurrent) return false;
      anchor.click();
      // Completion of the browser download cannot be observed by this adapter.
      await Future<void>.delayed(Duration.zero);
      return true;
    } finally {
      anchor.remove();
      web.URL.revokeObjectURL(url);
    }
  }
}
