import 'package:dio/dio.dart';

import '../../../core/commerce/commerce_controller.dart';
import '../../../core/communication/text_rules.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../../account/data/photo_picker_adapter.dart';
import '../../account/data/photo_validation.dart';
import '../data/review_models.dart';
import '../data/review_repository.dart';

class ReviewComposerController extends CommerceController {
  ReviewComposerController(
    super.session,
    this.repository,
    this.item,
    this.product, {
    this.reviewId,
  });
  final ReviewRepository repository;
  final String item, product;
  String? reviewId;
  int rating = 5;
  String draft = '';
  ({int rating, String body})? pending;
  ProductReview? review;
  List<ReviewPhoto> photos = const [];
  PickedBuyerImage? selected;
  bool textUncertain = false;
  bool busy = false,
      selecting = false,
      uploading = false,
      reconciling = false,
      uncertainPhoto = false,
      conflict = false;
  double? progress;
  CancelToken? _uploadCancellation;
  int _selectionOperation = 0;
  String? photoError;
  bool get locked => busy || uploading || selecting || reconciling;
  Future<void> submit({bool retry = false}) async {
    final credential = lease;
    if (credential == null ||
        locked ||
        coolingDown ||
        reviewId != null ||
        conflict ||
        pending != null && !retry) {
      return;
    }
    final invalid = plainTextError(draft, 2000);
    if (pending == null && invalid != null) {
      error = invalid;
      notifyListeners();
      return;
    }
    pending ??= (rating: rating, body: normalizedText(draft));
    final record = pending!, stamp = epoch;
    busy = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.create(
        credential,
        item,
        record.rating,
        record.body,
      );
      if (!current(stamp, credential)) return;
      review = value;
      reviewId = value.id;
      photos = value.photos;
      draft = '';
      pending = null;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      failure(e);
      if (e.uncertain) textUncertain = true;
      if (e.status == 409) conflict = true;
      if (e.status == 422 && !textUncertain) pending = null;
      if (e.status == 403 || e.status == 404) reset(preserveUnresolved: false);
    } finally {
      if (current(stamp, credential)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(PhotoPickerAdapter picker) async {
    final credential = lease;
    if (credential == null ||
        locked ||
        uncertainPhoto ||
        photos.length >= 5 ||
        reviewId == null) {
      return;
    }
    final stamp = epoch, operation = ++_selectionOperation;
    final id = reviewId;
    bool valid() =>
        current(stamp, credential) &&
        operation == _selectionOperation &&
        reviewId == id;
    selecting = true;
    photoError = null;
    notifyListeners();
    try {
      final image = await picker.pick(review: true);
      if (!valid() || image == null) return;
      selected = null;
      await validateBuyerImage(
        image.bytes,
        filename: image.filename,
        mimeType: image.mimeType,
        review: true,
      );
      if (valid()) selected = image;
    } on BuyerImageValidationException catch (e) {
      if (valid()) {
        selected = null;
        photoError = e.message;
      }
    } catch (_) {
      if (valid()) photoError = 'The image could not be read. Check photo access and choose another JPEG, PNG or WebP.';
    } finally {
      if (valid()) {
        selecting = false;
        notifyListeners();
      }
    }
  }

  void clearSelection({bool notify = true}) {
    _selectionOperation++;
    selecting = false;
    selected = null;
    if (!uploading && !uncertainPhoto) photoError = null;
    if (notify && !disposed) notifyListeners();
  }

  Future<void> upload() async {
    final credential = lease, image = selected;
    if (credential == null ||
        image == null ||
        locked ||
        coolingDown ||
        uncertainPhoto ||
        reviewId == null ||
        photos.length >= 5) {
      return;
    }
    final stamp = epoch;
    final cancellation = CancelToken();
    _uploadCancellation = cancellation;
    uploading = true;
    progress = null;
    photoError = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.upload(
        credential,
        reviewId!,
        image,
        cancelToken: cancellation,
        onProgress: (sent, total) {
          if (current(stamp, credential) &&
              identical(_uploadCancellation, cancellation) &&
              !cancellation.isCancelled) {
            progress = total > 0 ? (sent / total).clamp(0, 1) : null;
            notifyListeners();
          }
        },
      );
      if (!current(stamp, credential)) return;
      if (cancellation.isCancelled) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      photos = List.unmodifiable(
        {
          ...{for (final e in photos) e.id: e},
          value.id: value,
        }.values,
      );
      selected = null;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      photoError = describeFailure(e);
      fieldErrors = validationFields(e);
      if (e.uncertain) {
        uncertainPhoto = true;
        selected = null;
        photoError = 'This upload may have committed. Check the published Review before selecting another image.';
      }
      if (e.status == 409) {
        uncertainPhoto = true;
        selected = null;
      }
      if (e.status == 403 || e.status == 404) {
        review = null;
        photos = const [];
        selected = null;
        uncertainPhoto = true;
      }
    } catch (_) {
      if (current(stamp, credential)) {
        uncertainPhoto = true;
        selected = null;
        photoError = 'This upload may have saved. Check published photos before another upload.';
      }
    } finally {
      if (current(stamp, credential)) {
        _uploadCancellation = null;
        uploading = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  Future<void> reconcilePhotos() async {
    final credential = lease;
    if (credential == null || reviewId == null || locked || coolingDown) return;
    final stamp = epoch;
    reconciling = true;
    uncertainPhoto = true;
    photoError = null;
    notifyListeners();
    try {
      final value = await repository.canonical(
        product,
        reviewId!,
        isCurrent: () => current(stamp, credential),
      );
      if (!current(stamp, credential)) return;
      review = value;
      photos = value.photos;
      uncertainPhoto = false;
      selected = null;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      photoError = describeFailure(e);
      if (e.status == 403 || e.status == 404) {
        review = null;
        photos = const [];
        selected = null;
        uncertainPhoto = true;
      }
    } catch (_) {
      if (current(stamp, credential)) photoError = 'Published photos could not be checked. Try checking again before another upload.';
    } finally {
      if (current(stamp, credential)) {
        reconciling = false;
        notifyListeners();
      }
    }
  }

  void cancelUpload() {
    if (!uploading || _uploadCancellation == null) return;
    uncertainPhoto = true;
    selected = null;
    progress = null;
    photoError = 'Upload cancelled. It may have saved; check published photos before another upload.';
    _uploadCancellation!.cancel();
    notifyListeners();
  }

  @override
  void reset({required bool preserveUnresolved}) {
    if (preserveUnresolved && busy && pending != null) textUncertain = true;
    if (preserveUnresolved && uploading) {
      uncertainPhoto = true;
    }
    _uploadCancellation?.cancel();
    _uploadCancellation = null;
    _selectionOperation++;
    selected = null;
    photos = const [];
    review = null;
    draft = '';
    rating = 5;
    busy = selecting = uploading = reconciling = false;
    progress = null;
    photoError = null;
    if (!preserveUnresolved) {
      pending = null;
      uncertainPhoto = conflict = textUncertain = false;
      reviewId = null;
    } else if (reviewId != null) {
      uncertainPhoto = true;
    }
  }
}
