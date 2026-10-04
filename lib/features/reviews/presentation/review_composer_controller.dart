import 'dart:ui' as ui;

import '../../../core/commerce/commerce_controller.dart';
import '../../../core/communication/text_rules.dart';
import '../../../core/networking/api_failure.dart';
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
    final stamp = epoch;
    selecting = true;
    selected = null;
    photoError = null;
    notifyListeners();
    try {
      final image = await picker.pick();
      if (!current(stamp, credential) || image == null) return;
      if (!validProfilePhoto(
            length: image.bytes.lengthInBytes,
            filename: image.filename,
            mimeType: image.mimeType,
          ) ||
          image.filename.split('.').length != 2) {
        photoError = 'Choose JPEG, PNG or WebP under 10 MiB with one filename extension.';
        return;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 8000 ||
            descriptor.height > 8000 ||
            descriptor.width * descriptor.height > 40000000) {
          if (current(stamp, credential)) photoError = 'Use images with edges up to 8,000 pixels and at most 40 million pixels.';
          return;
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      if (current(stamp, credential)) selected = image;
    } catch (_) {
      if (current(stamp, credential)) {
        photoError =
            'The image could not be read. Choose another JPEG, PNG or WebP.';
      }
    } finally {
      if (current(stamp, credential)) {
        selecting = false;
        notifyListeners();
      }
    }
  }

  void clearSelection() {
    if (!uploading) {
      selected = null;
      photoError = null;
      notifyListeners();
    }
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
    uploading = true;
    progress = null;
    photoError = null;
    notifyListeners();
    try {
      final value = await repository.upload(
        credential,
        reviewId!,
        image,
        onProgress: (sent, total) {
          if (current(stamp, credential)) {
            progress = total > 0 ? sent / total : null;
            notifyListeners();
          }
        },
      );
      if (!current(stamp, credential)) return;
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
      if (e.uncertain) {
        uncertainPhoto = true;
        selected = null;
        photoError = 'This upload may have committed. Check the published Review before selecting another image.';
      }
      if (e.status == 409) {
        uncertainPhoto = true;
        selected = null;
      }
      if (e.status == 403 || e.status == 404) reset(preserveUnresolved: false);
    } finally {
      if (current(stamp, credential)) {
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
    photoError = null;
    notifyListeners();
    try {
      final value = await repository.canonical(product, reviewId!);
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
    } finally {
      if (current(stamp, credential)) {
        reconciling = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    if (preserveUnresolved && busy && pending != null) textUncertain = true;
    if (preserveUnresolved && uploading) {
      uncertainPhoto = true;
    }
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
