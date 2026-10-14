import 'package:aisley_mobile_buyer/app/theme.dart';
// Actual production transport/widgets/player with a local synthetic HTTP server.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:aisley_mobile_buyer/core/chat_media/attachment.dart';
import 'package:aisley_mobile_buyer/core/chat_media/content_repository.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/core/chat_media/private_file.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/chat_media/api_repository.dart';
import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/core/platform/http_adapter.dart';

late SemanticsHandle semantics;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  runApp(const Fixture());
}

class Fixture extends StatefulWidget {
  const Fixture({super.key});
  @override
  State<Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<Fixture> {
  bool active = true;
  late ChatMediaDraftController controller;
  String result = 'No probe';
  @override
  void initState() {
    super.initState();
    final http = Dio();
    configureHttpAdapter(http);
    final api = ApiClient(
      AppConfig(
        apiBaseUrl: Uri.base.origin,
        storefrontOrigin: Uri.base.origin,
        allowLocalHttp: true,
      ),
      privateClient: http,
    );
    final repo = ApiChatMediaRepository(
      api,
      () => SessionLease('synthetic-fixture', () => active, (_) {}),
    );
    controller = ChatMediaDraftController(repo);
  }

  ChatAttachment file(String kind, {String prefix = '11111111', int? size}) {
    final id = '$prefix-1111-4111-8111-111111111111';
    final length = kind == 'video'
        ? const int.fromEnvironment('VIDEO_BYTES')
        : 20;
    return ChatAttachment(
      id: id,
      kind: kind,
      filename: kind == 'video' ? 'Visit video.mp4' : 'Instructions.pdf',
      mimeType: kind == 'video' ? 'video/mp4' : 'application/pdf',
      byteSize: size ?? length,
      state: 'ready',
      previewUrl: '/api/v1/customer/chat-attachments/$id/preview',
      contentUrl: '/api/v1/customer/chat-attachments/$id/content',
    );
  }

  Future<void> probe(String prefix, int size) async {
    final read = ChatMediaRead();
    try {
      final bytes = await (controller.repository as ChatMediaContentRepository)
          .content(file('document', prefix: prefix, size: size), read);
      if (mounted && active) {
        setState(() => result = 'Probe accepted ${bytes.length}');
      }
    } catch (_) {
      if (mounted && active) setState(() => result = 'Probe safely rejected');
    } finally {
      read.cancel();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buyerTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          Uri.base.queryParameters['text'] == 'large' ? 2 : 1,
        ),
      ),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('G26 private media fixture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PrivateChatFile(attachment: file('video'), controller: controller),
          const SizedBox(height: 16),
          PrivateChatFile(
            attachment: file('document', prefix: '44444444'),
            controller: controller,
          ),
          Text(result),
          TextButton(
            onPressed: () => probe('22222222', 3),
            child: const Text('Probe oversized'),
          ),
          TextButton(
            onPressed: () => probe('33333333', 3),
            child: const Text('Probe redirect'),
          ),
          TextButton(
            onPressed: () => setState(() {
              active = false;
              controller.clear();
            }),
            child: const Text('End access'),
          ),
        ],
      ),
    ),
  );
}
