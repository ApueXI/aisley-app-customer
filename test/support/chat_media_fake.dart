import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';

const assetId = '11111111-1111-4111-8111-111111111111';

class MediaFake implements ChatMediaRepository {
  bool enabled = true, timeout = false;
  int picks = 0, uploads = 0, checks = 0, removals = 0;
  final keys = <String>[], contexts = <Map<String, Object?>>[];
  SelectedChatImage selected = SelectedChatImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGMQKl/wHx9mGBkKAM8iigGRRz6+AAAAAElFTkSuQmCC',
    ),
    'image.png',
    'image/png',
  );
  String state = 'ready';
  Completer<ChatAttachment>? delayed;
  ChatAttachment asset() => ChatAttachment(
    id: assetId,
    kind: 'image',
    filename: 'image.png',
    mimeType: 'image/png',
    byteSize: 3,
    state: state,
  );
  @override
  Future<bool> capabilities() async => enabled;
  @override
  Future<SelectedChatImage?> pick() async {
    picks++;
    return selected;
  }

  @override
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  ) async {
    uploads++;
    keys.add(key);
    contexts.add(context);
    if (timeout) {
      timeout = false;
      throw const ChatMediaFailure('Upload unconfirmed.');
    }
    if (delayed != null) return delayed!.future;
    return asset();
  }

  @override
  Future<ChatAttachment> status(String id) async {
    checks++;
    return asset();
  }

  @override
  Future<ChatAttachment> retry(String id) async => asset();
  @override
  Future<void> remove(String id) async {
    removals++;
  }

  @override
  Future<Uint8List> image(String url) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGMQKl/wHx9mGBkKAM8iigGRRz6+AAAAAElFTkSuQmCC',
  );
}
