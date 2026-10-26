import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chat_media_fake.dart';

import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/core/chat_media/image_widgets.dart';

void main() {
  test('text-only compatibility and strict attachment metadata', () {
    expect(ChatAttachment.list(null), isEmpty);
    expect(() => ChatAttachment.list([{}]), throwsFormatException);
    expect(
      chatImagePath(
        '/api/v1/customer/chat-attachments/$assetId/preview',
        'customer',
      ),
      'customer/chat-attachments/$assetId/preview',
    );
    for (final url in [
      'https://evil.test/api/v1/customer/chat-attachments/$assetId/content',
      '/api/v1/other/chat-attachments/$assetId/content',
      '/api/v1/customer/chat-attachments/$assetId/content?token=x',
      '//evil.test/image',
    ]) {
      expect(
        () => chatImagePath(url, 'customer'),
        throwsA(isA<ChatMediaFailure>()),
      );
    }
  });
  test('disabled uploads keep text usable and do not open picker', () async {
    final repo = MediaFake()..enabled = false;
    final c = ChatMediaDraftController(repo);
    await c.add({'conversation_id': assetId});
    expect(repo.picks, 0);
    expect(c.ready, isTrue);
    expect(c.error, contains('text'));
    c.dispose();
  });
  test(
    'uncertain upload freezes bytes key and context; explicit retry reconciles',
    () async {
      final repo = MediaFake()..timeout = true;
      final c = ChatMediaDraftController(repo);
      final context = <String, Object?>{'channel': 'shop', 'shop_id': assetId};
      await c.add(context);
      context['shop_id'] = 'changed';
      expect(c.ready, isFalse);
      expect(c.items.single.state, 'uncertain');
      await c.retry(c.items.single);
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.contexts[1]['shop_id'], assetId);
      expect(c.ids, [assetId]);
      c.dispose();
    },
  );
  test('processing blocks Send; locked send prevents media changes', () async {
    final repo = MediaFake()..state = 'pending';
    final c = ChatMediaDraftController(repo);
    await c.add({'conversation_id': assetId});
    expect(c.ready, isFalse);
    c.setForeground(false);
    repo.state = 'ready';
    await c.check(c.items.single);
    expect(c.ready, isTrue);
    c.locked = true;
    await c.add({'conversation_id': assetId});
    await c.remove(c.items.single);
    await c.retry(c.items.single);
    expect(repo.uploads, 1);
    expect(repo.removals, 0);
    expect(c.items.length, 1);
    c.dispose();
  });
  test('invalid format and exact 10 MiB rejected before transport; five images maximum', () async {
    final repo = MediaFake();
    final c = ChatMediaDraftController(repo);
    repo.selected = SelectedChatImage(
      Uint8List(10485760),
      'image.png',
      'image/png',
    );
    await c.add({});
    expect(repo.uploads, 0);
    repo.selected = SelectedChatImage(
      Uint8List(3),
      'image.png.exe',
      'image/png',
    );
    await c.add({});
    expect(repo.uploads, 0);
    repo.selected = MediaFake().selected;
    for (var i = 0; i < 6; i++) {
      await c.add({});
    }
    expect(repo.uploads, 5);
    expect(c.items.length, 5);
    c.dispose();
  });
  test('logout invalidates delayed upload and drops private buffers', () async {
    final repo = MediaFake()..delayed = Completer<ChatAttachment>();
    final c = ChatMediaDraftController(repo);
    final uploading = c.add({'conversation_id': assetId});
    await Future<void>.delayed(Duration.zero);
    expect(c.items.length, 1);
    c.clear();
    repo.delayed!.complete(repo.asset());
    await uploading;
    expect(c.items, isEmpty);
    expect(c.selecting, isFalse);
    c.dispose();
  });
  testWidgets(
    'confirmed send retains history; scope loss clears private images',
    (tester) async {
      final c = ChatMediaDraftController(MediaFake());
      const attachment = ChatAttachment(
        id: assetId,
        kind: 'image',
        filename: 'image.png',
        mimeType: 'image/png',
        byteSize: 68,
        state: 'ready',
        previewUrl: '/preview',
        contentUrl: '/content',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateChatImage(attachment: attachment, controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      c.clear(preserveHistory: true);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      c.clear();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Image access ended.'), findsOneWidget);
      expect(find.text('Retry image'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
  testWidgets('composer has reachable controls at 320px doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ChatMediaDraftController(MediaFake()..enabled = false);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ChatImageComposer(
                controller: c,
                contextValue: const {},
                enabled: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add image'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
