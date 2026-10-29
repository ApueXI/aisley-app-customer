part of 'api_client.dart';

bool supportedExternalCatalogImage(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'images.unsplash.com' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

extension PublicCatalogMediaTransport on ApiClient {
  Future<Uint8List> externalCatalogImageBytes(Uri uri) async {
    if (!supportedExternalCatalogImage(uri)) {
      throw const ApiFailure(FailureKind.decode);
    }
    final cancellation = CancelToken();
    final response =
        await _exchange(
          uri,
          'GET',
          null,
          null,
          cancellation,
          deadline: deadline,
          retryRead: true,
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'image/*'},
        ).timeout(
          deadline,
          onTimeout: () {
            cancellation.cancel('Request deadline exceeded.');
            throw const ApiFailure(FailureKind.timeout);
          },
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
}
