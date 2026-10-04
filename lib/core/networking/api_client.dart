import 'dart:async';

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
  final Duration deadline, readBackoff;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    SessionLease? lease,
  }) async {
    final uri = config.apiUri(path);
    final cancellation = CancelToken();
    lease?.attach(cancellation);
    try {
      return await _exchange(uri, method, body, lease, cancellation).timeout(
        deadline,
        onTimeout: () {
          cancellation.cancel();
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

  Future<Map<String, dynamic>> _exchange(
    Uri uri,
    String method,
    Map<String, dynamic>? body,
    SessionLease? lease,
    CancelToken cancellation,
  ) async {
    for (var attempt = 0; ; attempt++) {
      if (cancellation.isCancelled || lease != null && !lease.isCurrent()) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      try {
        final response = await (lease == null ? publicClient : privateClient)
            .requestUri<dynamic>(
              uri,
              data: body,
              cancelToken: cancellation,
              options: Options(
                method: method,
                headers: {
                  if (body != null) 'Content-Type': 'application/json',
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
          throw ApiFailure.response(response, clock());
        }
        if (response.data is! Map<String, dynamic>) {
          throw const ApiFailure(FailureKind.decode);
        }
        return response.data as Map<String, dynamic>;
      } on DioException catch (error) {
        final failure = ApiFailure(switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => FailureKind.timeout,
          DioExceptionType.cancel => FailureKind.cancelled,
          DioExceptionType.unknown when error.error is FormatException =>
            FailureKind.decode,
          _ => FailureKind.offline,
        });
        if (!_canRetry(method, attempt, failure)) throw failure;
      } on ApiFailure catch (failure) {
        if (!_canRetry(method, attempt, failure)) rethrow;
      }
      // One bounded read retry is included in the overall request deadline.
      await Future<void>.delayed(readBackoff);
    }
  }

  bool _canRetry(String method, int attempt, ApiFailure failure) =>
      method == 'GET' &&
      attempt == 0 &&
      (failure.kind == FailureKind.offline ||
          failure.kind == FailureKind.timeout ||
          failure.status != null && failure.status! >= 500);
  void close() {
    publicClient.close(force: true);
    privateClient.close(force: true);
  }
}
