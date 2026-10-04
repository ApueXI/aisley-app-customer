import 'dart:typed_data';

import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_models.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_repository.dart';

import 'fakes.dart';

class FakeAccountRepository implements AccountRepository {
  CustomerAccount value = CustomerAccount.parse(
    fixture('account-management', 'op-007')['account'],
  );
  Future<CustomerAccount> Function()? onAccount;
  Future<CustomerAccount> Function(ProfileInput)? onProfile;
  Future<void> Function()? onPassword;
  Future<Uint8List> Function()? onPhoto;
  Future<CustomerAccount> Function()? onUpload;
  Future<PromotionPreference> Function()? onPreference;
  int accountReads = 0,
      profileWrites = 0,
      passwordWrites = 0,
      photoReads = 0,
      uploads = 0;
  @override
  Future<CustomerAccount> account(SessionLease lease) async {
    accountReads++;
    return onAccount == null ? value : onAccount!();
  }

  @override
  Future<CustomerAccount> updateProfile(
    SessionLease lease,
    ProfileInput input,
  ) async {
    profileWrites++;
    return onProfile == null ? value : onProfile!(input);
  }

  @override
  Future<void> updatePassword(
    SessionLease lease, {
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    passwordWrites++;
    if (onPassword != null) await onPassword!();
  }

  @override
  Future<Uint8List> profilePhoto(
    SessionLease lease,
    String? versionedUrl,
  ) async {
    photoReads++;
    return onPhoto == null ? Uint8List.fromList([1, 2, 3]) : onPhoto!();
  }

  @override
  Future<CustomerAccount> uploadPhoto(
    SessionLease lease, {
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploads++;
    return onUpload == null ? value : onUpload!();
  }

  @override
  Future<CustomerAccount> removePhoto(SessionLease lease) async => value;
  @override
  Future<PromotionPreference> promotionPreference(SessionLease lease) async =>
      onPreference == null
      ? const PromotionPreference(optedIn: false, optedInAt: null)
      : onPreference!();
  @override
  Future<PromotionPreference> setPromotionPreference(
    SessionLease lease,
    bool optedIn,
  ) async => PromotionPreference(optedIn: optedIn, optedInAt: null);
}
