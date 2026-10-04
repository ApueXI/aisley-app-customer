import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';

import 'dart:typed_data';

class PhotoController extends PrivateFeatureController {
  PhotoController(super.session, this.repository);
  final AccountRepository repository;
  Uint8List? bytes;
  String? photoUrl;
  bool loading = false, uploading = false, removing = false;
  double? progress;

  Future<void> load([String? url]) async {
    final lease = currentLease;
    if (lease == null) return;
    final generation = featureGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.profilePhoto(lease, url ?? photoUrl);
      if (isCurrentEpoch(generation, lease)) {
        bytes = value;
        photoUrl = url ?? photoUrl;
        requiresReconciliation = false;
      }
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        if (failure.status == 404 || failure.status == 403) {
          bytes = null;
          photoUrl = null;
          requiresReconciliation = false;
        } else {
          error = describeFailure(failure);
        }
      }
    } catch (_) {
      if (isCurrentEpoch(generation, lease)) {
        error = 'The profile photo is unavailable.';
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> upload({
    required Uint8List data,
    required String filename,
    required String mimeType,
  }) async {
    final type = mimeType.toLowerCase();
    final extension = filename.split('.').last.toLowerCase();
    const formats = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    if (data.isEmpty ||
        data.lengthInBytes >= 10485760 ||
        formats[extension] == null ||
        formats[extension] != type) {
      error = 'Choose a JPEG, PNG or WebP photo smaller than 10 MiB.';
      notifyListeners();
      return false;
    }
    final lease = currentLease;
    if (lease == null || uploading || coolingDown || requiresReconciliation) {
      return false;
    }
    final generation = featureGeneration;
    uploading = true;
    progress = null;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final account = await repository.uploadPhoto(
        lease,
        bytes: data,
        filename: filename,
        mimeType: type,
        onProgress: (sent, total) {
          if (isCurrentEpoch(generation, lease)) {
            progress = total > 0 ? sent / total : null;
            notifyListeners();
          }
        },
      );
      if (!isCurrentEpoch(generation, lease)) return false;
      photoUrl = account.profile.profilePhotoUrl;
      await load(photoUrl);
      await session.refreshNavigation();
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        if (failure.uncertain) {
          requiresReconciliation = true;
          error =
              'The upload outcome is uncertain. Checking the current photo…';
          await load();
        }
        if (isCurrentEpoch(generation, lease)) {
          error ??= describeFailure(failure);
        }
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        uploading = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  Future<bool> remove() async {
    final lease = currentLease;
    if (lease == null || removing || coolingDown || requiresReconciliation) {
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
        if (failure.uncertain) {
          requiresReconciliation = true;
          await load();
        }
        if (isCurrentEpoch(generation, lease)) {
          error ??= describeFailure(failure);
        }
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
  void onClear() {
    bytes = null;
    photoUrl = null;
    loading = false;
    uploading = false;
    removing = false;
    progress = null;
  }
}
