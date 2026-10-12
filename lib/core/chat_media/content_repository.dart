import 'dart:async';
import 'dart:typed_data';

import 'attachment.dart';

/// One foreground read. Scope loss and disposal abort the underlying transport.
class ChatMediaRead {
  final _cancelled = Completer<void>();
  Future<void> get cancelled => _cancelled.future;
  bool get isCurrent => !_cancelled.isCompleted;
  void cancel() {
    if (isCurrent) _cancelled.complete();
  }
}

abstract interface class ChatMediaContentRepository {
  Future<Uint8List> content(
    ChatAttachment attachment,
    ChatMediaRead read, {
    bool preview = false,
  });
}

const documentFormats = {
  'pdf': 'application/pdf',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
  'odp': 'application/vnd.oasis.opendocument.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
};

int historicalMediaLimit(ChatAttachment attachment) {
  final parts = attachment.filename.split('.');
  if (attachment.state != 'ready' ||
      parts.length != 2 ||
      parts.first.trim().isEmpty ||
      attachment.filename.length > 180 ||
      RegExp(r'[\x00-\x1f\x7f/\\]').hasMatch(attachment.filename)) {
    throw const ChatMediaFailure('This attachment is unavailable.');
  }
  final extension = parts.last.toLowerCase();
  final mime = switch (attachment.kind) {
    'video' => extension == 'mp4' ? 'video/mp4' : null,
    'document' => documentFormats[extension],
    'image' => const {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    }[extension],
    _ => null,
  };
  final limit = attachment.kind == 'video'
      ? 30 * 1024 * 1024
      : attachment.kind == 'image'
      ? 10 * 1024 * 1024 - 1
      : 10 * 1024 * 1024;
  if (mime == null ||
      mime != attachment.mimeType ||
      attachment.byteSize < 1 ||
      attachment.byteSize > limit) {
    throw const ChatMediaFailure(
      'This attachment format or size is unsupported.',
    );
  }
  return limit;
}

String attachmentPath(ChatAttachment attachment, String role, bool preview) {
  historicalMediaLimit(attachment);
  final url = preview ? attachment.previewUrl : attachment.contentUrl;
  if (url == null ||
      (preview && attachment.kind == 'document') ||
      url !=
          '/api/v1/$role/chat-attachments/${attachment.id}/${preview ? 'preview' : 'content'}') {
    throw const ChatMediaFailure('This attachment is unavailable.');
  }
  return chatImagePath(url, role);
}
