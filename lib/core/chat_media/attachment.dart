import 'dart:typed_data';

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.kind,
    required this.filename,
    required this.mimeType,
    required this.byteSize,
    required this.state,
    this.previewUrl,
    this.contentUrl,
    this.errorCode,
  });
  final String id, kind, filename, mimeType, state;
  final int byteSize;
  final String? previewUrl, contentUrl, errorCode;
  factory ChatAttachment.parse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value['id'] as String) ||
        !const ['image', 'video', 'document'].contains(value['kind']) ||
        !const [
          'pending',
          'ready',
          'rejected',
          'failed',
          'deleted',
        ].contains(value['state']) ||
        value['filename'] is! String ||
        value['mime_type'] is! String ||
        value['byte_size'] is! int ||
        (value['byte_size'] as int) < 1) {
      throw const FormatException('Invalid chat attachment');
    }
    for (final key in ['preview_url', 'content_url', 'error_code']) {
      if (value[key] != null && value[key] is! String) {
        throw const FormatException('Invalid chat attachment field');
      }
    }
    return ChatAttachment(
      id: value['id'] as String,
      kind: value['kind'] as String,
      filename: value['filename'] as String,
      mimeType: value['mime_type'] as String,
      byteSize: value['byte_size'] as int,
      state: value['state'] as String,
      previewUrl: value['preview_url'] as String?,
      contentUrl: value['content_url'] as String?,
      errorCode: value['error_code'] as String?,
    );
  }
  static List<ChatAttachment> list(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 5) {
      throw const FormatException('Invalid attachments');
    }
    return List.unmodifiable(value.map(ChatAttachment.parse));
  }
}

class SelectedChatImage {
  const SelectedChatImage(this.bytes, this.filename, this.mimeType);
  final Uint8List bytes;
  final String filename, mimeType;
}

class ChatMediaFailure implements Exception {
  const ChatMediaFailure(this.message, {this.status, this.retryAfter});
  final String message;
  final int? status;
  final Duration? retryAfter;
}

abstract interface class ChatMediaRepository {
  Future<bool> capabilities();
  Future<SelectedChatImage?> pick();
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  );
  Future<ChatAttachment> status(String id);
  Future<ChatAttachment> retry(String id);
  Future<void> remove(String id);
  Future<Uint8List> image(String url);
}

String chatImagePath(String url, String role) {
  final path = Uri.tryParse(url);
  if (path == null ||
      path.hasScheme ||
      path.hasAuthority ||
      path.hasQuery ||
      path.hasFragment ||
      !RegExp(
        '^/api/v1/$role/chat-attachments/[0-9a-fA-F-]{36}/(preview|content)\u0024',
      ).hasMatch(url)) {
    throw const ChatMediaFailure('This private image is unavailable.');
  }
  return url.substring('/api/v1/'.length);
}
