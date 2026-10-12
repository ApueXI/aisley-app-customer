part of 'api_client.dart';

extension PrivateMediaTransport on ApiClient {
  Future<Uint8List> privateMediaBytes(
    String path, {
    required int maxBytes,
    required String mimeType,
    required SessionLease lease,
    required bool Function() isCurrent,
    required Future<void> cancelled,
    int? expectedBytes,
  }) async {
    final cancellation = CancelToken();
    lease.attach(cancellation);
    unawaited(cancelled.then((_) => cancellation.cancel()));
    final timer = Timer(
      const Duration(seconds: 60),
      () => cancellation.cancel(),
    );
    try {
      if (!isCurrent() || !lease.isCurrent()) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      final response = await privateClient.requestUri<ResponseBody>(
        config.apiUri(path),
        cancelToken: cancellation,
        options: Options(
          method: 'GET',
          responseType: ResponseType.stream,
          extra: {
            'privateMediaPolicy': PrivateMediaPolicy(
              maxBytes,
              mimeType,
              expectedBytes,
              () =>
                  isCurrent() && lease.isCurrent() && !cancellation.isCancelled,
            ),
          },
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            'Authorization': 'Bearer ${lease.bearer}',
            'Accept': mimeType,
            'Cache-Control': 'no-store',
          },
        ),
      );
      if (response.statusCode != 200) {
        final error = BytesBuilder(copy: false);
        Object? data;
        if ((response.statusCode ?? 0) >= 400 && response.data != null) {
          await for (final chunk in response.data!.stream.timeout(deadline)) {
            if (!isCurrent() ||
                !lease.isCurrent() ||
                error.length + chunk.length > 65536) {
              break;
            }
            error.add(chunk);
          }
          try {
            data = jsonDecode(utf8.decode(error.takeBytes()));
          } catch (_) {}
        }
        throw ApiFailure.response(
          Response<dynamic>(
            requestOptions: response.requestOptions,
            data: data,
            statusCode: response.statusCode,
            headers: response.headers,
          ),
          clock(),
        );
      }
      final type = response.headers
          .value('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final lengthHeader = response.headers.value('content-length');
      final length = lengthHeader == null ? null : int.tryParse(lengthHeader);
      if ((mimeType == 'image/*'
              ? !const ['image/jpeg', 'image/png', 'image/webp'].contains(type)
              : type != mimeType) ||
          (lengthHeader != null && length == null) ||
          (length != null &&
              (length < 1 ||
                  length > maxBytes ||
                  expectedBytes != null && length != expectedBytes))) {
        throw const ApiFailure(FailureKind.decode);
      }
      final builder = BytesBuilder(copy: false);
      final body = response.data;
      if (body == null) throw const ApiFailure(FailureKind.decode);
      await for (final chunk in body.stream.timeout(deadline)) {
        if (!isCurrent() || !lease.isCurrent() || cancellation.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled);
        }
        if (builder.length + chunk.length > maxBytes ||
            expectedBytes != null &&
                builder.length + chunk.length > expectedBytes) {
          throw const ApiFailure(FailureKind.decode);
        }
        builder.add(chunk);
      }
      if (!isCurrent() || !lease.isCurrent() || cancellation.isCancelled) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      if (builder.isEmpty ||
          length != null && builder.length != length ||
          expectedBytes != null && builder.length != expectedBytes) {
        throw const ApiFailure(FailureKind.decode);
      }
      return builder.takeBytes();
    } on ApiFailure catch (failure) {
      if (lease.isCurrent()) lease.onFailure(failure);
      rethrow;
    } on DioException catch (e) {
      throw ApiFailure(
        e.error is FormatException
            ? FailureKind.decode
            : e.type == DioExceptionType.cancel
            ? FailureKind.cancelled
            : FailureKind.offline,
      );
    } on TimeoutException {
      throw const ApiFailure(FailureKind.timeout);
    } finally {
      timer.cancel();
      cancellation.cancel();
      lease.detach(cancellation);
    }
  }
}
