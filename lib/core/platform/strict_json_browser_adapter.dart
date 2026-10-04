import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';

@JS('fetch')
external JSPromise<_FetchResponse> _fetch(JSString url, JSObject options);

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}

extension type _FetchResponse(JSObject _) implements JSObject {
  external int get status;
  external _FetchHeaders get headers;
  external JSPromise<JSString> text();
}

extension type _FetchHeaders(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

/// Phase 1 authenticated transport: JSON only, no cookies or redirects.
/// Upload transport belongs to its later-phase platform adapters.
class StrictJsonBrowserAdapter implements HttpClientAdapter {
  final _controllers = <_AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    final controller = _AbortController();
    _controllers.add(controller);
    var cancelled = false;
    cancelFuture?.then((_) {
      cancelled = true;
      controller.abort();
    });
    try {
      if (requestStream != null &&
          options.contentType != Headers.jsonContentType) {
        throw DioException(
          requestOptions: options,
          error: const FormatException('Unsupported browser payload.'),
        );
      }
      final body = requestStream == null
          ? null
          : await utf8.decoder.bind(requestStream).join();
      if (cancelled) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
      final response = await _fetch(
        options.uri.toString().toJS,
        {
              'method': options.method,
              'headers': {
                for (final entry in options.headers.entries)
                  entry.key: entry.value.toString(),
              },
              'credentials': 'omit',
              'cache': 'no-store',
              'referrerPolicy': 'no-referrer',
              'redirect': 'error',
              'signal': controller.signal,
              'body': ?body,
            }.jsify()
            as JSObject,
      ).toDart;
      final text = (await response.text().toDart).toDart;
      final headers = <String, List<String>>{};
      response.headers.forEach(
        ((JSString value, JSString name) {
          headers[name.toDart.toLowerCase()] = [value.toDart];
        }).toJS,
      );
      return ResponseBody.fromString(text, response.status, headers: headers);
    } on DioException {
      rethrow;
    } catch (_) {
      throw DioException(
        requestOptions: options,
        type: cancelled
            ? DioExceptionType.cancel
            : DioExceptionType.connectionError,
      );
    } finally {
      _controllers.remove(controller);
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final controller in _controllers) {
      controller.abort();
    }
    _controllers.clear();
  }
}
