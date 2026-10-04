import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/communication/text_rules.dart';
import '../../account/data/photo_picker_adapter.dart';
import '../../account/data/photo_validation.dart';
import 'review_models.dart';

class ReviewRepository {
  ReviewRepository(this.api);
  final ApiClient api;
  Future<ReviewPage> list(String product, [int page = 1]) async =>
      ReviewPage.parse(
        await api.request(
          'GET',
          'products/${requireUuid(product)}/reviews',
          queryParameters: {'page': page, 'limit': 10},
        ),
      );
  Future<ProductReview> create(
    SessionLease lease,
    String item,
    int rating,
    String body,
  ) async {
    if (rating < 1 || rating > 5) {
      throw const ApiFailure(FailureKind.http, status: 422);
    }
    return ProductReview.parse(
      Wire(
        await api.request(
          'POST',
          'customer/order-items/${requireUuid(item)}/review',
          lease: lease,
          body: {'rating': rating, 'body': checkedText(body, 2000)},
        ),
      ).object('data'),
    );
  }

  Future<ReviewPhoto> upload(
    SessionLease lease,
    String review,
    PickedBuyerImage image, {
    void Function(int, int)? onProgress,
  }) async {
    if (!validProfilePhoto(
          length: image.bytes.lengthInBytes,
          filename: image.filename,
          mimeType: image.mimeType,
        ) ||
        image.filename.split('.').length != 2) {
      throw const ApiFailure(
        FailureKind.http,
        status: 422,
        fields: {
          'image': [
            'Choose a JPEG, PNG or WebP photo smaller than 10 MiB with one extension.',
          ],
        },
      );
    }
    return ReviewPhoto.parse(
      Wire(
        await api.uploadBytes(
          'customer/reviews/${requireUuid(review)}/images',
          fieldName: 'image',
          bytes: image.bytes,
          filename: image.filename,
          mimeType: image.mimeType,
          lease: lease,
          onSendProgress: onProgress,
        ),
      ).object('data'),
    );
  }

  // No private Review GET exists. Traverse public pages to find the canonical ID.
  Future<ProductReview> canonical(String product, String review) async {
    final seen = <String>{};
    for (var page = 1; page <= 10000; page++) {
      final value = await list(product, page);
      if (value.page != page) throw const ApiFailure(FailureKind.decode);
      for (final item in value.items) {
        if (item.id == review) return item;
      }
      final progress = value.items.any((e) => !seen.contains(e.id));
      seen.addAll(value.items.map((e) => e.id));
      if (!value.hasMore || !progress) break;
    }
    throw const ApiFailure(FailureKind.http, status: 404);
  }
}
