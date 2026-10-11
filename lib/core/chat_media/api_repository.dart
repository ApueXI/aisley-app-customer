import 'dart:convert';
import 'dart:typed_data';

import '../networking/api_client.dart';
import '../networking/api_failure.dart';
import '../../features/account/data/photo_picker_adapter.dart';
import 'attachment.dart';

class ApiChatMediaRepository implements ChatMediaRepository {
  ApiChatMediaRepository(this.api, this.lease, {this.onDenial});
  final ApiClient api;
  final SessionLease? Function() lease;
  final void Function()? onDenial;
  static const base = 'customer/chat-attachments';
  SessionLease get credential =>
      lease() ??
      (throw const ChatMediaFailure(
        'Sign in to use chat images.',
        status: 401,
      ));
  Future<T> _call<T>(Future<T> Function(SessionLease) action) async {
    final current = credential;
    try {
      return await action(current);
    } on ApiFailure catch (e) {
      if (current.isCurrent() && (e.status == 403 || e.status == 404)) {
        onDenial?.call();
      }
      throw ChatMediaFailure(
        e.description,
        status: e.status,
        retryAfter: e.retryAt?.difference(DateTime.now()),
      );
    } on FormatException {
      throw const ChatMediaFailure(
        'The image response was not understood. Retry the original request.',
      );
    }
  }

  Future<ChatAttachment> _json(String method, String path) => _call(
    (c) async => ChatAttachment.parse(
      (await api.request(method, path, lease: c))['data'],
    ),
  );
  @override
  Future<bool> capabilities() => _call((c) async {
    final data = (await api.request('GET', base, lease: c))['data'];
    if (data is! Map || data['enabled'] is! bool) throw const FormatException();
    return data['enabled'] as bool;
  });
  @override
  Future<SelectedChatImage?> pick() async {
    final image = await PhotoPickerAdapter().pick();
    return image == null
        ? null
        : SelectedChatImage(image.bytes, image.filename, image.mimeType);
  }

  @override
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  ) => _call(
    (c) async => ChatAttachment.parse(
      (await api.uploadBytes(
        base,
        fieldName: 'file',
        bytes: image.bytes,
        filename: image.filename,
        mimeType: image.mimeType,
        lease: c,
        fields: {'context': jsonEncode(context)},
        idempotencyKey: key,
      ))['data'],
    ),
  );
  @override
  Future<ChatAttachment> status(String id) => _json('GET', '$base/$id');
  @override
  Future<ChatAttachment> retry(String id) => _json('POST', '$base/$id/retry');
  @override
  Future<void> remove(String id) => _call((c) async {
    await api.request('DELETE', '$base/$id', lease: c);
  });
  @override
  Future<Uint8List> image(String url) => _call((c) async {
    final bytes = await api.requestBytes(
      chatImagePath(url, 'customer'),
      lease: c,
    );
    if (bytes.isEmpty || bytes.length >= 10485760) {
      throw const FormatException();
    }
    return bytes;
  });
}
