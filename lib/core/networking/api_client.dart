import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_failure.dart';

/// An in-memory credential bound to one controller generation.
class SessionLease {
  SessionLease(this.bearer, this.isCurrent, this.onFailure) {
    unawaited(
      cancellation.whenCancel.then((_) {
        for (final request in _requests.toList()) {
          request.cancel();
        }
        _requests.clear();
      }),
    );
  }
  final String bearer;
  final bool Function() isCurrent;
  final void Function(ApiFailure) onFailure;
  final CancelToken cancellation = CancelToken();
  final _requests = <CancelToken>{};
  void attach(CancelToken request) {
    if (cancellation.isCancelled || !isCurrent()) {
      throw const ApiFailure(FailureKind.cancelled);
    }
    _requests.add(request);
  }

  void detach(CancelToken request) => _requests.remove(request);
  @override
  String toString() => 'SessionLease';
}

class ApiClient {
  ApiClient(
    this.config, {
    Dio? publicClient,
    Dio? privateClient,
    DateTime Function()? clock,
    this.deadline = const Duration(seconds: 15),
    this.uploadDeadline = const Duration(seconds: 60),
    this.readBackoff = const Duration(milliseconds: 250),
  }) : publicClient = publicClient ?? Dio(),
       privateClient = privateClient ?? Dio(),
       clock = clock ?? DateTime.now {
    for (final client in [this.publicClient, this.privateClient]) {
      client.options = BaseOptions(
        connectTimeout: deadline,
        sendTimeout: deadline,
        receiveTimeout: deadline,
        followRedirects: false,
        validateStatus: (_) => true,
        headers: {'Accept': 'application/json'},
      );
    }
  }
  final AppConfig config;
  final Dio publicClient, privateClient;
  final DateTime Function() clock;
  final Duration deadline, uploadDeadline, readBackoff;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, Object?>? queryParameters,
    SessionLease? lease,
    bool readOnlyOperation = false,
  }) async {
    final response = await _send(
      method,
      path,
      data: body,
      queryParameters: queryParameters,
      lease: lease,
      deadline: deadline,
      retryRead: method == 'GET' || readOnlyOperation,
      headers: {if (body != null) 'Content-Type': Headers.jsonContentType},
    );
    if (response.statusCode == 204) {
      return const <String, dynamic>{};
    }
    if (response.data is! Map<String, dynamic>) {
      throw const ApiFailure(FailureKind.decode);
    }
    return response.data as Map<String, dynamic>;
  }

  Future<Uint8List> requestBytes(
    String path, {
    Map<String, Object?>? queryParameters,
    SessionLease? lease,
  }) async {
    final response = await _send(
      'GET',
      path,
      queryParameters: queryParameters,
      lease: lease,
      deadline: deadline,
      retryRead: true,
      responseType: ResponseType.bytes,
      headers: {'Accept': 'image/*'},
    );
    final contentType = response.headers.value(Headers.contentTypeHeader);
    if (contentType == null ||
        !contentType.toLowerCase().startsWith('image/')) {
      throw const ApiFailure(FailureKind.decode);
    }
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw const ApiFailure(FailureKind.decode);
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required SessionLease lease,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final multipart = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _send(
      'POST',
      path,
      data: multipart,
      lease: lease,
      deadline: uploadDeadline,
      retryRead: false,
      onSendProgress: onSendProgress,
    );
    if (response.data is! Map<String, dynamic>) {
      throw const ApiFailure(FailureKind.decode);
    }
    return response.data as Map<String, dynamic>;
  }

  Future<Response<dynamic>> _send(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    SessionLease? lease,
    required Duration deadline,
    required bool retryRead,
    ResponseType? responseType,
    Map<String, Object?> headers = const {},
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final baseUri = config.apiUri(path);
    if (queryParameters != null &&
        queryParameters.values.any(
          (value) =>
              value != null &&
              value is! String &&
              value is! num &&
              value is! bool,
        )) {
      throw const ApiFailure(FailureKind.decode);
    }
    final query = queryParameters == null
        ? null
        : {
            for (final entry in queryParameters.entries)
              if (entry.value != null) entry.key: entry.value.toString(),
          };
    final uri = query == null
        ? baseUri
        : baseUri.replace(queryParameters: query);
    final cancellation = CancelToken();
    lease?.attach(cancellation);
    try {
      return await _exchange(
        uri,
        method,
        data,
        lease,
        cancellation,
        deadline: deadline,
        retryRead: retryRead,
        responseType: responseType,
        headers: headers,
        onSendProgress: onSendProgress,
      ).timeout(
        deadline,
        onTimeout: () {
          cancellation.cancel('Request deadline exceeded.');
          throw const ApiFailure(FailureKind.timeout);
        },
      );
    } on ApiFailure catch (failure) {
      if (lease != null && lease.isCurrent()) lease.onFailure(failure);
      rethrow;
    } finally {
      lease?.detach(cancellation);
    }
  }

  Future<Response<dynamic>> _exchange(
    Uri uri,
    String method,
    Object? data,
    SessionLease? lease,
    CancelToken cancellation, {
    required Duration deadline,
    required bool retryRead,
    ResponseType? responseType,
    required Map<String, Object?> headers,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (cancellation.isCancelled || lease != null && !lease.isCurrent()) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      try {
        final response = await (lease == null ? publicClient : privateClient)
            .requestUri<dynamic>(
              uri,
              data: data,
              cancelToken: cancellation,
              onSendProgress: onSendProgress,
              options: Options(
                method: method,
                responseType: responseType,
                sendTimeout: deadline,
                receiveTimeout: deadline,
                headers: {
                  ...headers,
                  if (data is Map<String, dynamic>)
                    'Content-Type': Headers.jsonContentType,
                  if (lease != null) 'Authorization': 'Bearer ${lease.bearer}',
                },
              ),
            );
        if (lease != null && !lease.isCurrent()) {
          throw const ApiFailure(FailureKind.cancelled);
        }
        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          if (response.data is List<int> &&
              response.headers
                      .value(Headers.contentTypeHeader)
                      ?.startsWith('application/json') ==
                  true &&
              (response.data as List<int>).length <= 65536) {
            try {
              response.data = jsonDecode(
                utf8.decode(response.data as List<int>),
              );
            } catch (_) {}
          }
          throw ApiFailure.response(response, clock());
        }
        return response;
      } on DioException catch (error) {
        final failure = error.response != null
            ? ApiFailure.response(error.response!, clock())
            : ApiFailure(switch (error.type) {
                DioExceptionType.connectionTimeout ||
                DioExceptionType.sendTimeout ||
                DioExceptionType.receiveTimeout => FailureKind.timeout,
                DioExceptionType.cancel => FailureKind.cancelled,
                DioExceptionType.unknown when error.error is FormatException =>
                  FailureKind.decode,
                _ => FailureKind.offline,
              });
        if (!_canRetry(retryRead, attempt, failure)) throw failure;
      } on ApiFailure catch (failure) {
        if (!_canRetry(retryRead, attempt, failure)) rethrow;
      }
      await Future<void>.delayed(readBackoff);
    }
  }

  bool _canRetry(bool retryRead, int attempt, ApiFailure failure) =>
      retryRead &&
      attempt == 0 &&
      (failure.kind == FailureKind.offline ||
          failure.kind == FailureKind.timeout ||
          failure.status != null && failure.status! >= 500);

  void close() {
    publicClient.close(force: true);
    privateClient.close(force: true);
  }
}
