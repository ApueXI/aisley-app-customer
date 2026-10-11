import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import '../data/photo_validation.dart';

/// Session-owned photo writes survive navigation; selected files stay in the form.
class PhotoController extends PrivateFeatureController {
  PhotoController(super.session, this.repository);
  final AccountRepository repository;
  Uint8List? bytes;
  String? photoUrl;
  bool loading = false, uploading = false, removing = false;
  bool selectionConsumed = false;
  double? progress;
  CancelToken? _uploadCancellation;
  bool get busy => loading || uploading || removing;

  Future<void> load() async {
    final lease = currentLease;
    if (lease == null || busy || coolingDown) return;
    final generation = featureGeneration;
    loading = true;
    requiresReconciliation = true;
    error = null;
    notifyListeners();
    try {
      final account = await repository.account(lease);
      if (!isCurrentEpoch(generation, lease)) return;
      if (account.id != session.customer?.id ||
          account.role != 'customer' ||
          account.status != 'active') {
        throw const ApiFailure(FailureKind.decode);
      }
      await _readPhoto(account, generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        if (failure.status == 403 || failure.status == 404) {
          bytes = null;
          photoUrl = null;
        }
        error = describeFailure(failure);
      }
    } catch (_) {
      if (isCurrentEpoch(generation, lease)) {
        error = 'The current profile photo could not be checked. Refresh before another upload.';
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _readPhoto(
    CustomerAccount account,
    int generation,
    SessionLease lease,
  ) async {
    final url = account.profile.profilePhotoUrl;
    try {
      final value = await repository.profilePhoto(lease, url);
      if (!isCurrentEpoch(generation, lease)) return;
      bytes = value;
      photoUrl = url;
      requiresReconciliation = false;
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(generation, lease)) return;
      // Only the authorized photo endpoint's missing-photo result confirms absence.
      if (failure.status == 404) {
        bytes = null;
        photoUrl = null;
        requiresReconciliation = false;
      } else {
        if (failure.status == 403) {
          bytes = null;
          photoUrl = null;
        }
        error = describeFailure(failure);
      }
    } catch (_) {
      if (isCurrentEpoch(generation, lease)) {
        error = 'The photo preview could not be refreshed. Refresh current photo to try again.';
      }
    }
  }

  Future<bool> upload({
    required Uint8List data,
    required String filename,
    required String mimeType,
  }) async {
    final lease = currentLease;
    if (lease == null || busy || coolingDown || requiresReconciliation) {
      return false;
    }
    if (!validProfilePhoto(
      length: data.lengthInBytes,
      filename: filename,
      mimeType: mimeType,
    )) {
      error =
          'Choose JPEG, PNG or WebP under 10 MiB with one filename extension.';
      notifyListeners();
      return false;
    }
    final generation = featureGeneration;
    final cancellation = CancelToken();
    _uploadCancellation = cancellation;
    uploading = true;
    selectionConsumed = false;
    progress = null;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final account = await repository.uploadPhoto(
        lease,
        bytes: data,
        filename: filename,
        mimeType: mimeType.toLowerCase(),
        cancelToken: cancellation,
        onProgress: (sent, total) {
          if (isCurrentEpoch(generation, lease) &&
              identical(_uploadCancellation, cancellation) &&
              !cancellation.isCancelled) {
            progress = total > 0 ? (sent / total).clamp(0, 1) : null;
            notifyListeners();
          }
        },
      );
      if (!isCurrentEpoch(generation, lease)) return false;
      if (cancellation.isCancelled) {
        throw const ApiFailure(FailureKind.cancelled);
      }
      selectionConsumed = true;
      requiresReconciliation = true;
      bytes = null;
      photoUrl = account.profile.profilePhotoUrl;
      await _readPhoto(account, generation, lease);
      await session.refreshNavigation();
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        error = describeFailure(failure);
        if (failure.uncertain) {
          selectionConsumed = true;
          requiresReconciliation = true;
          error = 'This upload may have saved. Refresh current photo before choosing another image.';
        }
        if (failure.status == 403 || failure.status == 404) {
          bytes = null;
          photoUrl = null;
          requiresReconciliation = true;
          selectionConsumed = true;
        }
      }
      return false;
    } catch (_) {
      if (isCurrentEpoch(generation, lease)) {
        selectionConsumed = true;
        requiresReconciliation = true;
        error = 'This upload may have saved. Refresh current photo before choosing another image.';
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        uploading = false;
        progress = null;
        _uploadCancellation = null;
        notifyListeners();
      }
    }
  }

  void cancelUpload() {
    if (!uploading || _uploadCancellation == null) return;
    selectionConsumed = true;
    requiresReconciliation = true;
    progress = null;
    error = 'Upload cancelled. It may have saved; refresh current photo before another upload.';
    _uploadCancellation!.cancel();
    notifyListeners();
  }

  Future<bool> remove() async {
    final lease = currentLease;
    if (lease == null || busy || coolingDown || requiresReconciliation) {
      return false;
    }
    final generation = featureGeneration;
    removing = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      await repository.removePhoto(lease);
      if (!isCurrentEpoch(generation, lease)) return false;
      bytes = null;
      photoUrl = null;
      await session.refreshNavigation();
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        requiresReconciliation =
            failure.uncertain || failure.status == 403 || failure.status == 404;
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) {
          bytes = null;
          photoUrl = null;
        }
      }
      return false;
    } catch (_) {
      if (isCurrentEpoch(generation, lease)) {
        requiresReconciliation = true;
        error = 'Removal could not be confirmed. Refresh current photo.';
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        removing = false;
        notifyListeners();
      }
    }
  }

  @override
  void clearPrivate() {
    final unresolved =
        (uploading || removing || requiresReconciliation) &&
        session.customer != null &&
        session.verifiedLease?.isCurrent() == true;
    featureGeneration++;
    clearCooldown();
    onClear();
    error = null;
    fieldErrors = const {};
    requiresReconciliation = unresolved;
    if (!isDisposed) notifyListeners();
  }

  @override
  void onClear() {
    _uploadCancellation?.cancel();
    _uploadCancellation = null;
    bytes = null;
    photoUrl = null;
    loading = uploading = removing = false;
    selectionConsumed = true;
    progress = null;
  }
}
