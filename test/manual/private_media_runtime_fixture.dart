// Test-only entrypoint. Credentials come from the disposable loopback fixture,
// stay in memory, and are never compiled into the application or persisted.
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/chat_media/api_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/core/chat_media/media_platform.dart';
import 'package:aisley_mobile_buyer/core/chat_media/private_file.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/http_adapter.dart';
import 'package:aisley_mobile_buyer/features/courier_messages/data/courier_repository.dart';

late SemanticsHandle semantics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  await cleanAbandonedChatMedia();
  runApp(MaterialApp(theme: buyerTheme(), home: const RuntimeFixture()));
}

class RuntimeFixture extends StatefulWidget {
  const RuntimeFixture({super.key});
  @override
  State<RuntimeFixture> createState() => _RuntimeFixtureState();
}

class _RuntimeFixtureState extends State<RuntimeFixture> {
  ApiClient? api;
  SessionLease? lease;
  ChatMediaDraftController? media;
  List<ChatAttachment> attachments = [];
  String? conversation;
  String result = 'Connecting to isolated runtime…';
  bool active = true, busy = false;
  final bootstrap = Dio();
  final sessionUrl = const String.fromEnvironment(
    'MEDIA_SESSION_URL',
    defaultValue: 'http://localhost:8766/fixture-session',
  );

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final uri = Uri.parse(sessionUrl);
      if (uri.scheme != 'http' ||
          !['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
        throw const FormatException('Loopback fixture required');
      }
      final response = await bootstrap.get<Map<String, dynamic>>(sessionUrl);
      if (!mounted || !active) return;
      final data = response.data!;
      var origin = data['api_origin'] as String;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        origin = Uri.parse(origin).replace(host: '10.0.2.2').origin;
      }
      final http = Dio();
      configureHttpAdapter(http);
      final client = ApiClient(
        AppConfig(
          apiBaseUrl: origin,
          storefrontOrigin: origin,
          allowLocalHttp: true,
        ),
        privateClient: http,
      );
      final current = SessionLease(
        data['token'] as String,
        () => active,
        (_) {},
      );
      await client.request('GET', 'customer/auth/me', lease: current);
      if (!mounted || !active) return;
      final repository = ApiChatMediaRepository(
        client,
        () => active ? current : null,
      );
      final allowed = await repository.capabilities();
      if (!mounted || !active || !allowed) throw StateError('Unavailable');
      setState(() {
        api = client;
        lease = current;
        media = ChatMediaDraftController(repository);
        conversation = data['conversation_id'] as String;
        attachments = ChatAttachment.list(data['attachments']);
        result = 'Authenticated runtime ready';
      });
    } catch (_) {
      if (mounted && active) {
        setState(() => result = 'Runtime connection failed');
      }
    }
  }

  String _key() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _sendImage() async {
    if (busy || !active || media == null) return;
    setState(() => busy = true);
    try {
      final response = await bootstrap.get<List<int>>(
        Uri.parse(sessionUrl).resolve('/fixture-image').toString(),
        options: Options(responseType: ResponseType.bytes),
      );
      final repository = media!.repository;
      final image = SelectedChatImage(
        Uint8List.fromList(response.data!),
        'photo.png',
        'image/png',
      );
      var asset = await repository.upload(image, {
        'conversation_id': conversation,
      }, _key());
      for (var i = 0; i < 30 && asset.state == 'pending' && active; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        asset = await repository.status(asset.id);
      }
      if (!active || asset.state != 'ready') {
        throw StateError('Image not ready');
      }
      final key = _key();
      final body = <String, dynamic>{
        'attachment_ids': [asset.id],
      };
      final chat = CourierChatRepository(api!);
      final first = await chat.write(lease!, conversation, body, key);
      final replay = await chat.write(lease!, conversation, body, key);
      if (first.$2.id != replay.$2.id) throw StateError('Replay mismatch');
      if (mounted && active) {
        setState(() => result = 'Image sent and replay verified');
      }
    } catch (_) {
      if (mounted && active) {
        setState(() => result = 'Runtime image check failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await api?.request('POST', 'customer/auth/logout', lease: lease);
    } finally {
      active = false;
      lease?.cancellation.cancel();
      media?.clear();
      if (mounted) {
        setState(() {
          attachments = [];
          result = 'Runtime signed out';
        });
      }
    }
  }

  @override
  void dispose() {
    active = false;
    lease?.cancellation.cancel();
    media?.dispose();
    api?.privateClient.close(force: true);
    bootstrap.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('G26 local runtime')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(result),
        if (media != null && active) ...[
          for (final attachment in attachments)
            PrivateChatFile(attachment: attachment, controller: media!),
          TextButton(
            onPressed: busy ? null : _sendImage,
            child: const Text('Verify image send'),
          ),
          TextButton(onPressed: _logout, child: const Text('Sign out')),
        ],
      ],
    ),
  );
}
