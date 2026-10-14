import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/chat_media/api_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/content_repository.dart';

import '../support/private_media_fake.dart';
import '../support/chat_media_fake.dart';

import 'package:dio/dio.dart';

import '../support/communication_harness.dart';

class Harness {
  final h = CommunicationHarness();
  int chunksRead = 0;
  late ApiChatMediaRepository repo;
  int get requestCount => h.adapter.requests.length;
  static Future<Harness> create(
    List<List<int>> chunks,
    Map<String, List<String>> headers, {
    int status = 200,
  }) async {
    final harness = Harness();
    await harness.h.initialize();
    Stream<Uint8List> stream() async* {
      for (final chunk in chunks) {
        harness.chunksRead++;
        yield Uint8List.fromList(chunk);
      }
    }

    harness.h.reply = (_) => ResponseBody(stream(), status, headers: headers);
    harness.repo = ApiChatMediaRepository(
      harness.h.api,
      () => harness.h.session.verifiedLease,
    );
    return harness;
  }

  void close() => h.dispose();
  void checkRequest() {
    final request = h.adapter.requests.single;
    expect(
      request.uri.path,
      '/api/v1/customer/chat-attachments/$assetId/content',
    );
    expect(request.headers['Authorization'], 'Bearer synthetic-token');
    expect(request.followRedirects, isFalse);
    expect(request.responseType, ResponseType.stream);
  }
}

void main() {
  test('ready private content uses exact role route, MIME and bearer without redirects', () async {
    final h = await Harness.create(
      [
        [1, 2, 3],
      ],
      {
        'content-type': ['application/pdf'],
      },
    );
    expect(await h.repo.content(receivedFile(), ChatMediaRead()), [1, 2, 3]);
    h.checkRequest();
    h.close();
  });
  for (final type in ['video/mp4', ...documentFormats.values]) {
    test('permitted MIME retrieval $type', () async {
      final ext = type == 'video/mp4'
          ? 'mp4'
          : documentFormats.entries.firstWhere((e) => e.value == type).key;
      final h = await Harness.create(
        [
          [1, 2, 3],
        ],
        {
          'content-type': ['$type; charset=UTF-8'],
        },
      );
      await h.repo.content(
        receivedFile(
          kind: type == 'video/mp4' ? 'video' : 'document',
          filename: 'safe.$ext',
          mime: type,
        ),
        ChatMediaRead(),
      );
      h.close();
    });
  }
  for (final status in [302, 401, 403, 404, 429, 500]) {
    test('HTTP $status is surfaced without successful private bytes', () async {
      final h = await Harness.create(
        [
          [123, 125],
        ],
        {
          'content-type': ['application/json'],
          'retry-after': ['2'],
        },
        status: status,
      );
      await expectLater(
        h.repo.content(receivedFile(), ChatMediaRead()),
        throwsA(
          isA<ChatMediaFailure>().having((e) => e.status, 'status', status),
        ),
      );
      h.close();
    });
  }
  test(
    'foreign role, foreign ID and absolute delivery URL never dispatch',
    () async {
      final h = await Harness.create(
        [
          [1, 2, 3],
        ],
        {
          'content-type': ['application/pdf'],
        },
      );
      for (final url in [
        'https://evil.test/file.pdf',
        '/api/v1/courier/chat-attachments/$assetId/content',
        '/api/v1/customer/chat-attachments/22222222-2222-4222-8222-222222222222/content',
        '/api/v1/customer/chat-attachments/$assetId/content?token=x',
      ]) {
        final asset = ChatAttachment(
          id: assetId,
          kind: 'document',
          filename: 'safe.pdf',
          mimeType: 'application/pdf',
          byteSize: 3,
          state: 'ready',
          contentUrl: url,
        );
        await expectLater(
          h.repo.content(asset, ChatMediaRead()),
          throwsA(isA<ChatMediaFailure>()),
        );
      }
      expect(h.requestCount, 0);
      h.close();
    },
  );
  test('declared oversize fails before body consumption', () async {
    final h = await Harness.create(
      [
        [1, 2, 3],
      ],
      {
        'content-type': ['application/pdf'],
        'content-length': ['10485761'],
      },
    );
    await expectLater(
      h.repo.content(receivedFile(), ChatMediaRead()),
      throwsA(isA<ChatMediaFailure>()),
    );
    expect(h.chunksRead, 0);
    h.close();
  });
  test('chunked content exceeding declared DTO stops before retaining later chunks', () async {
    final h = await Harness.create(
      [
        [1, 2, 3],
        [4],
        [5],
      ],
      {
        'content-type': ['application/pdf'],
      },
    );
    await expectLater(
      h.repo.content(receivedFile(), ChatMediaRead()),
      throwsA(isA<ChatMediaFailure>()),
    );
    expect(h.chunksRead, lessThanOrEqualTo(2));
    h.close();
  });
  for (final chunks in <List<List<int>>>[
    [],
    [
      [1, 2],
    ],
  ]) {
    test(
      'empty or truncated response is not exportable ${chunks.length}',
      () async {
        final h = await Harness.create(chunks, {
          'content-type': ['application/pdf'],
        });
        await expectLater(
          h.repo.content(receivedFile(), ChatMediaRead()),
          throwsA(isA<ChatMediaFailure>()),
        );
        h.close();
      },
    );
  }
  test('wrong response MIME rejects bytes', () async {
    final h = await Harness.create(
      [
        [1, 2, 3],
      ],
      {
        'content-type': ['text/html'],
      },
    );
    await expectLater(
      h.repo.content(receivedFile(), ChatMediaRead()),
      throwsA(isA<ChatMediaFailure>()),
    );
    h.close();
  });
  test('cancelled scope cannot dispatch content', () async {
    final h = await Harness.create(
      [
        [1, 2, 3],
      ],
      {
        'content-type': ['application/pdf'],
      },
    );
    final read = ChatMediaRead()..cancel();
    await expectLater(
      h.repo.content(receivedFile(), read),
      throwsA(isA<ChatMediaFailure>()),
    );
    expect(h.requestCount, 0);
    h.close();
  });
  test('historical 8 MB-plus MP4 remains readable', () async {
    final size = 8000001;
    final h = await Harness.create(
      [Uint8List(size)],
      {
        'content-type': ['video/mp4'],
      },
    );
    final bytes = await h.repo.content(
      receivedFile(kind: 'video', size: size),
      ChatMediaRead(),
    );
    expect(bytes.length, size);
    h.close();
  });
}
