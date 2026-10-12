import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class PrivateMediaPolicy {
  PrivateMediaPolicy(
    this.maxBytes,
    this.mimeType,
    this.expectedBytes,
    this.current,
  );
  final int maxBytes;
  final String mimeType;
  final int? expectedBytes;
  final bool Function() current;
}

/// Enforce at the transport edge, before Dio's response stream forwarding.
class BoundedMediaAdapter implements HttpClientAdapter {
  BoundedMediaAdapter(this.inner);
  final HttpClientAdapter inner;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final policy = options.extra['privateMediaPolicy'];
    if (policy is! PrivateMediaPolicy) {
      return inner.fetch(options, requestStream, cancelFuture);
    }
    final abortion = Completer<void>();
    void abort() {
      if (!abortion.isCompleted) abortion.complete();
    }

    final body = await inner.fetch(
      options,
      requestStream,
      Future.any<void>([?cancelFuture, abortion.future]),
    );
    final success = body.statusCode == 200;
    final maxBytes = success ? policy.maxBytes : 65536;
    final rawLength = body.headers['content-length']?.first;
    final length = rawLength == null ? null : int.tryParse(rawLength);
    final type = body.headers['content-type']?.first
        .split(';')
        .first
        .trim()
        .toLowerCase();
    final validType = policy.mimeType == 'image/*'
        ? const ['image/jpeg', 'image/png', 'image/webp'].contains(type)
        : type == policy.mimeType;
    if (!policy.current() ||
        success &&
            (!validType ||
                rawLength != null && length == null ||
                length != null &&
                    (length < 1 ||
                        length > maxBytes ||
                        policy.expectedBytes != null &&
                            length != policy.expectedBytes))) {
      abort();
      throw DioException(
        requestOptions: options,
        error: const FormatException('Invalid private media.'),
      );
    }
    final source = body.stream;
    late StreamController<Uint8List> stream;
    StreamSubscription<Uint8List>? subscription;
    var count = 0, stopped = false;
    void stop([Object? error]) {
      if (stopped) return;
      stopped = true;
      if (error != null) stream.addError(error);
      unawaited(subscription?.cancel() ?? Future<void>.value());
      if (error != null) abort();
      unawaited(stream.close());
    }

    stream = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        subscription = source.listen(
          (chunk) {
            if (stopped) return;
            if (!policy.current() ||
                count + chunk.length > maxBytes ||
                success &&
                    policy.expectedBytes != null &&
                    count + chunk.length > policy.expectedBytes!) {
              stop(const FormatException('Private media exceeded its limit.'));
              return;
            }
            count += chunk.length;
            stream.add(chunk);
          },
          onError: (Object error, StackTrace stack) {
            stop(error);
          },
          onDone: () {
            if (success &&
                (count == 0 ||
                    length != null && count != length ||
                    policy.expectedBytes != null &&
                        count != policy.expectedBytes)) {
              stop(const FormatException('Incomplete private media.'));
            } else {
              stop();
            }
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        stopped = true;
        abort();
        return subscription?.cancel();
      },
    );
    return ResponseBody(
      stream.stream,
      body.statusCode,
      headers: body.headers,
      onClose: () {
        stopped = true;
        unawaited(subscription?.cancel() ?? Future<void>.value());
        abort();
      },
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
