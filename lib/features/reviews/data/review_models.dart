import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/api_page.dart';
import '../../../core/commerce/commerce_value.dart';

class ReviewPhoto {
  ReviewPhoto.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    url = w.string('url');
    mimeType = w.string('mimeType');
    width = w.positiveInt('width');
    height = w.positiveInt('height');
  }
  late final String id, url, mimeType;
  late final int width, height;
}

class SellerResponse {
  SellerResponse.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    shopName = w.string('shopName');
    body = w.string('body');
    publishedAt = w.timestamp('publishedAt');
  }
  late final String id, shopName, body;
  late final DateTime? publishedAt;
}

class ProductReview {
  ProductReview.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    rating = w.integer('rating');
    body = w.string('body');
    if (rating < 1 || rating > 5) throw const ApiFailure(FailureKind.decode);
    verified = w.boolean('verifiedPurchase');
    author = w.string('authorLabel');
    at = w.timestamp('createdAt');
    photos = w.list('photos', ReviewPhoto.parse);
    final raw = w.field('sellerResponse');
    response = raw == null ? null : SellerResponse.parse(raw);
  }
  late final String id, body, author;
  late final int rating;
  late final bool verified;
  late final DateTime? at;
  late final List<ReviewPhoto> photos;
  late final SellerResponse? response;
}

class ReviewSummary {
  ReviewSummary.parse(Object? json) {
    final w = Wire(json);
    average = w.nullableNumber('averageRating');
    count = nonnegative(w, 'reviewCount');
    final d = Wire(w.object('distribution'));
    distribution = Map.unmodifiable({
      for (var i = 1; i <= 5; i++) '$i': nonnegative(d, '$i'),
    });
    if (average != null && (average! < 1 || average! > 5)) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final double? average;
  late final int count;
  late final Map<String, int> distribution;
}

class ReviewPage extends ApiPage<ProductReview> {
  ReviewPage.parse(Object? json) : super.parse(json, ProductReview.parse) {
    summary = ReviewSummary.parse(Wire(json).object('summary'));
  }
  late final ReviewSummary summary;
}
