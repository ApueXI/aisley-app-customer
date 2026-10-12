import 'dart:async';
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

@JS('Uint8Array')
extension type _JsUint8Array._(JSObject _) implements JSObject {
  external factory _JsUint8Array(JSAny? source);
  external int get length;
  external int operator [](int index);
  external void operator []=(int index, int value);
}

extension type _FetchResponse(JSObject _) implements JSObject {
  external _FetchStream? get body;
  external int get status;
  external _FetchHeaders get headers;
  external JSPromise<JSString> text();
  external JSPromise<JSObject> arrayBuffer();
}

extension type _FetchHeaders(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

extension type _FetchStream(JSObject _) implements JSObject {
  external _FetchReader getReader();
}

extension type _FetchReader(JSObject _) implements JSObject {
  external JSPromise<_FetchChunk> read();
  external JSPromise<JSAny?> cancel();
}

extension type _FetchChunk(JSObject _) implements JSObject {
  external bool get done;
  external _JsUint8Array get value;
}

/// Browser Fetch transport with omitted cookies, rejected redirects and bytes.
class StrictJsonBrowserAdapter implements HttpClientAdapter {
  StrictJsonBrowserAdapter({this.publicMapProvider = false});
  final bool publicMapProvider;
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
    var cancelled = false, streaming = false;
    cancelFuture?.then((_) {
      cancelled = true;
      controller.abort();
    });
    try {
      final contentType = options.contentType ?? '';
      Object? body;
      if (requestStream != null) {
        if (contentType == Headers.jsonContentType) {
          body = await utf8.decoder.bind(requestStream).join();
        } else if (contentType.toLowerCase().startsWith(
          'multipart/form-data;',
        )) {
          final bytes = await _collect(requestStream);
          final jsBytes = _JsUint8Array(bytes.length.toJS);
          for (var index = 0; index < bytes.length; index++) {
            jsBytes[index] = bytes[index];
          }
          body = jsBytes;
        } else {
          throw DioException(
            requestOptions: options,
            error: const FormatException('Unsupported browser payload.'),
          );
        }
      }
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
              'referrerPolicy':
                  publicMapProvider &&
                      const {
                        'https://api.geoapify.com',
                        'https://maps.geoapify.com',
                      }.contains(options.uri.origin)
                  ? 'strict-origin-when-cross-origin'
                  : 'no-referrer',
              'redirect': 'error',
              'signal': controller.signal,
              'body': ?body,
            }.jsify()
            as JSObject,
      ).toDart;
      final headers = <String, List<String>>{};
      response.headers.forEach(
        ((JSString value, JSString name) {
          headers[name.toDart.toLowerCase()] = [value.toDart];
        }).toJS,
      );
      if (options.responseType == ResponseType.stream) {
        final reader = response.body?.getReader();
        if (reader == null) {
          throw const FormatException('Missing response stream.');
        }
        streaming = true;
        Stream<Uint8List> chunks() async* {
          try {
            while (!cancelled) {
              final chunk = await reader.read().toDart;
              if (chunk.done) break;
              final value = chunk.value;
              final bytes = Uint8List(value.length);
              for (var i = 0; i < value.length; i++) {
                bytes[i] = value[i];
              }
              yield bytes;
            }
          } finally {
            controller.abort();
            _controllers.remove(controller);
            try {
              await reader.cancel().toDart;
            } catch (_) {}
          }
        }

        return ResponseBody(
          chunks(),
          response.status,
          headers: headers,
          onClose: () {
            controller.abort();
            _controllers.remove(controller);
          },
        );
      }
      if (options.responseType == ResponseType.bytes) {
        final buffer = await response.arrayBuffer().toDart;
        final view = _JsUint8Array(buffer);
        final bytes = Uint8List(view.length);
        for (var index = 0; index < view.length; index++) {
          bytes[index] = view[index];
        }
        return ResponseBody.fromBytes(bytes, response.status, headers: headers);
      }
      final text = (await response.text().toDart).toDart;
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
      if (!streaming) _controllers.remove(controller);
    }
  }

  Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
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
