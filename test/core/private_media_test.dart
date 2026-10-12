import 'package:aisley_mobile_buyer/app/theme.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/content_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/core/chat_media/private_file.dart';
import 'package:aisley_mobile_buyer/core/chat_media/private_video_viewer.dart';

import '../support/private_media_fake.dart';
import '../support/chat_media_fake.dart';

void main() {
  for (final size in [7999999, 8000000, 8000001]) {
    test('new image selection boundary $size', () async {
      final repo = MediaFake()
        ..selected = SelectedChatImage(
          Uint8List(size),
          'image.png',
          'image/png',
        );
      final controller = ChatMediaDraftController(repo);
      await controller.add({});
      expect(repo.uploads, size <= 8000000 ? 1 : 0);
      expect(controller.hasImages, size <= 8000000);
      controller.dispose();
    });
  }
  test(
    'permanent 422 requires removal; unchanged upload is never retried',
    () async {
      final repo = RejectedFake();
      final c = ChatMediaDraftController(repo);
      await c.add({});
      expect(c.items.single.state, 'rejected');
      await c.retry(c.items.single);
      await c.upload(c.items.single);
      expect(repo.uploads, 1);
      expect(c.ready, isFalse);
      await c.remove(c.items.single);
      expect(c.ready, isTrue);
      c.dispose();
    },
  );
  test('all permitted documents and MP4 retain historical read bounds', () {
    for (final format in documentFormats.entries) {
      final asset = receivedFile(
        filename: 'safe.${format.key}',
        mime: format.value,
        size: 10485760,
      );
      expect(historicalMediaLimit(asset), 10485760);
      expect(attachmentPath(asset, 'customer', false), contains(asset.id));
    }
    expect(
      historicalMediaLimit(receivedFile(kind: 'video', size: 31457280)),
      31457280,
    );
    expect(
      historicalMediaLimit(
        receivedFile(
          kind: 'image',
          filename: 'old.png',
          mime: 'image/png',
          size: 8000001,
        ),
      ),
      10485759,
    );
  });
  for (final asset in [
    receivedFile(filename: 'fake.pdf.exe'),
    receivedFile(filename: '../safe.pdf'),
    receivedFile(mime: 'text/html'),
    receivedFile(state: 'pending'),
    receivedFile(kind: 'video', size: 31457281),
    receivedFile(size: 10485761),
    receivedFile(kind: 'audio'),
  ]) {
    test(
      'reject unsupported metadata ${asset.filename}/${asset.kind}/${asset.state}/${asset.byteSize}',
      () {
        expect(
          () => historicalMediaLimit(asset),
          throwsA(isA<ChatMediaFailure>()),
        );
      },
    );
  }
  testWidgets(
    'video loads only on explicit view and never autoplays; Close disposes',
    (tester) async {
      final repo = ContentFake(), platform = PlatformFake();
      final c = ChatMediaDraftController(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateChatFile(
              attachment: receivedFile(kind: 'video'),
              controller: c,
              platform: platform,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.prepares, 0);
      expect(repo.contentIds, isEmpty);
      await tester.tap(find.text('View video'));
      await tester.pumpAndSettle();
      expect(platform.prepares, 1);
      expect(platform.player.playCalls, 0);
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(platform.player.playing, isTrue);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(platform.player.playing, isFalse);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(platform.player.closed, isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('scope loss clears active playback and blocks retry', (
    tester,
  ) async {
    final repo = ContentFake(), platform = PlatformFake();
    final c = ChatMediaDraftController(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateChatFile(
            attachment: receivedFile(kind: 'video'),
            controller: c,
            platform: platform,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View video'));
    await tester.pumpAndSettle();
    c.clear();
    await tester.pumpAndSettle();
    expect(platform.player.closed, isTrue);
    expect(find.text('Play'), findsNothing);
    expect(find.text('Video access ended.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'document requires explicit download; cancelled chooser gives truthful feedback',
    (tester) async {
      final repo = ContentFake(), platform = PlatformFake()..saveResult = false;
      final c = ChatMediaDraftController(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateChatFile(
              attachment: receivedFile(),
              controller: c,
              platform: platform,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.contentIds, isEmpty);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(platform.saves, 1);
      expect(find.text('Download cancelled.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('logout aborts pending document content and never opens save', (
    tester,
  ) async {
    final repo = ContentFake()..delayedContent = Completer<Uint8List>();
    final platform = PlatformFake();
    final c = ChatMediaDraftController(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateChatFile(
            attachment: receivedFile(),
            controller: c,
            platform: platform,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Download'));
    await tester.pump();
    c.clear();
    expect(repo.reads.single.isCurrent, isFalse);
    repo.delayedContent!.complete(Uint8List(3));
    await tester.pumpAndSettle();
    expect(platform.saves, 0);
    expect(find.text('Download'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('scope loss cancels an open save dialog', (tester) async {
    final repo = ContentFake(),
        platform = PlatformFake()..delayedSave = Completer<bool>();
    final c = ChatMediaDraftController(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateChatFile(
            attachment: receivedFile(),
            controller: c,
            platform: platform,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump();
    c.clear();
    expect(platform.saveRead!.isCurrent, isFalse);
    platform.delayedSave!.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Download requested'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('changed attachment identity cancels late old download', (
    tester,
  ) async {
    final repo = ContentFake()..delayedContent = Completer<Uint8List>();
    final platform = PlatformFake();
    final c = ChatMediaDraftController(repo);
    Widget view(String id) => MaterialApp(
      home: Scaffold(
        body: PrivateChatFile(
          attachment: receivedFile(id: id),
          controller: c,
          platform: platform,
        ),
      ),
    );
    await tester.pumpWidget(view(assetId));
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pumpWidget(view('22222222-2222-4222-8222-222222222222'));
    expect(repo.reads.single.isCurrent, isFalse);
    repo.delayedContent!.complete(Uint8List(3));
    await tester.pumpAndSettle();
    expect(platform.saves, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'video fetch failure is retryable and late Close response cannot start player',
    (tester) async {
      final repo = ContentFake()..failure = const ChatMediaFailure('Offline');
      final platform = PlatformFake();
      final c = ChatMediaDraftController(repo), read = ChatMediaRead();
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateVideoViewer(
            attachment: receivedFile(kind: 'video'),
            controller: c,
            read: read,
            platform: platform,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry video'), findsOneWidget);
      repo.failure = null;
      repo.delayedContent = Completer<Uint8List>();
      await tester.tap(find.text('Retry video'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      repo.delayedContent!.complete(Uint8List(3));
      await tester.pumpAndSettle();
      expect(platform.prepares, 0);
      c.dispose();
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final brightness in [Brightness.light]) {
      testWidgets(
        'document/video controls at $width/$brightness with doubled text',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = ChatMediaDraftController(ContentFake());
          await tester.pumpWidget(
            MaterialApp(
              theme: buyerTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    PrivateChatFile(
                      attachment: receivedFile(),
                      controller: c,
                      platform: PlatformFake(),
                    ),
                    PrivateChatFile(
                      attachment: receivedFile(kind: 'video'),
                      controller: c,
                      platform: PlatformFake(),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Download'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          c.dispose();
        },
      );
    }
  }
}

class RejectedFake extends MediaFake {
  @override
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  ) async {
    uploads++;
    throw const ChatMediaFailure('Validation rejected', status: 422);
  }
}
