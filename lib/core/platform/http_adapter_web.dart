import 'package:dio/dio.dart';

import 'strict_json_browser_adapter.dart';

void configureHttpAdapter(Dio client, {bool publicMapProvider = false}) {
  // XHR cannot disable redirects. Both public auth JSON (passwords) and private
  // bearer exchanges need Fetch's error redirect mode and omitted cookies.
  client.httpClientAdapter = StrictJsonBrowserAdapter(
    publicMapProvider: publicMapProvider,
  );
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Fetch cannot report bytes transferred; draining multipart bytes is not upload progress.
        options.onSendProgress = null;
        handler.next(options);
      },
    ),
  );
}
