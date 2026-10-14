import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/chat_media/content_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/media_platform_native.dart';

import '../support/private_media_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('aisley/private_chat_documents');
  test('Android chooses destination before handing off bytes; cancellation never writes', () async {
    final chosen = Completer<String?>(), calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'choose') return chosen.future;
          if (call.method == 'cancel' && !chosen.isCompleted) {
            chosen.complete(null);
          }
          return null;
        });
    final read = ChatMediaRead();
    final platform = NativeChatMediaPlatform(isAndroid: true);
    final save = platform.save(Uint8List(3), receivedFile(), read);
    await Future<void>.delayed(Duration.zero);
    expect((calls.single.arguments as Map).containsKey('bytes'), isFalse);
    read.cancel();
    expect(await save, isFalse);
    expect(calls.map((c) => c.method), ['choose', 'cancel', 'release']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('successful Android export transfers bytes only after chooser and serializes saves', () async {
    final calls = <MethodCall>[];
    final chosen = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'choose' ? chosen.future : null;
        });
    final platform = NativeChatMediaPlatform(isAndroid: true),
        read = ChatMediaRead();
    final save = platform.save(
      Uint8List.fromList([1, 2, 3]),
      receivedFile(),
      read,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await platform.save(Uint8List(3), receivedFile(), ChatMediaRead()),
      isFalse,
    );
    chosen.complete('opaque-destination');
    expect(await save, isTrue);
    expect(calls.map((c) => c.method), ['choose', 'write', 'release']);
    expect((calls[1].arguments as Map)['bytes'], [1, 2, 3]);
    read.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 3);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('scope already lost never invokes picker', () async {
    final read = ChatMediaRead()..cancel();
    expect(
      await NativeChatMediaPlatform(isAndroid: true)
          .save(Uint8List(3), receivedFile(), read),
      isFalse,
    );
  });
}
