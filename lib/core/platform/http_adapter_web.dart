import 'package:dio/dio.dart';

import 'strict_json_browser_adapter.dart';

void configureHttpAdapter(Dio client) {
  // XHR cannot disable redirects. Both public auth JSON (passwords) and private
  // bearer exchanges need Fetch's error redirect mode and omitted cookies.
  client.httpClientAdapter = StrictJsonBrowserAdapter();
}
