import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/core/chat_media/api_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';

const asset = {
  'id': customerId,
  'kind': 'image',
  'filename': 'image.png',
  'mime_type': 'image/png',
  'byte_size': 3,
  'state': 'ready',
};
void main() {
  test('Buyer upload sends exact context UUID key and multipart fields with scoped bearer', () async {
    final h = CommunicationHarness();
    await h.initialize();
    h.reply = (o) => jsonReply({'data': asset}, status: 201);
    final repo = ApiChatMediaRepository(h.api, () => h.session.verifiedLease);
    await repo.upload(
      SelectedChatImage(
        Uint8List.fromList([1, 2, 3]),
        'image.png',
        'image/png',
      ),
      {'conversation_id': customerId},
      otherId,
    );
    final request = h.adapter.requests.single;
    expect(request.uri.path, '/api/v1/customer/chat-attachments');
    expect(request.headers['Idempotency-Key'], otherId);
    expect(request.headers['Authorization'], 'Bearer synthetic-token');
    final form = request.data as FormData;
    expect(form.fields.single.key, 'context');
    expect(form.fields.single.value, '{"conversation_id":"$customerId"}');
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'image.png');
    await expectLater(
      repo.image('/api/v1/courier/chat-attachments/$customerId/content'),
      throwsA(isA<ChatMediaFailure>()),
    );
    expect(h.adapter.requests.length, 1);
    h.dispose();
  });
}
