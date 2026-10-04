import 'dart:typed_data';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import 'account_models.dart';
import 'photo_validation.dart';
import '../../../core/networking/api_failure.dart';

abstract interface class AccountRepository {
  Future<CustomerAccount> account(SessionLease lease);
  Future<CustomerAccount> updateProfile(SessionLease lease, ProfileInput input);
  Future<void> updatePassword(
    SessionLease lease, {
    required String currentPassword,
    required String password,
    required String confirmation,
  });
  Future<Uint8List> profilePhoto(SessionLease lease, String? versionedUrl);
  Future<CustomerAccount> uploadPhoto(
    SessionLease lease, {
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  });
  Future<CustomerAccount> removePhoto(SessionLease lease);
  Future<PromotionPreference> promotionPreference(SessionLease lease);
  Future<PromotionPreference> setPromotionPreference(
    SessionLease lease,
    bool optedIn,
  );
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this.api);
  final ApiClient api;

  @override
  Future<CustomerAccount> account(SessionLease lease) async {
    final response = await api.request('GET', 'customer/account', lease: lease);
    return CustomerAccount.parse(response['account']);
  }

  @override
  Future<CustomerAccount> updateProfile(
    SessionLease lease,
    ProfileInput input,
  ) async {
    final response = await api.request(
      'PATCH',
      'customer/account/profile',
      body: input.toJson(),
      lease: lease,
    );
    return ProfileMutation.parse(response).account;
  }

  @override
  Future<void> updatePassword(
    SessionLease lease, {
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    final response = await api.request(
      'PATCH',
      'customer/account/password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': confirmation,
      },
      lease: lease,
    );
    Wire(response).string('message');
  }

  @override
  Future<Uint8List> profilePhoto(
    SessionLease lease,
    String? versionedUrl,
  ) async {
    if (versionedUrl == null || versionedUrl.isEmpty) {
      return api.requestBytes('customer/account/profile-photo', lease: lease);
    }
    final uri = Uri.tryParse(versionedUrl);
    if (uri == null || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid private image URL.');
    }
    final resolved = uri.hasAuthority
        ? uri
        : api.config.apiBase.resolveUri(uri);
    if (!api.config.trustsApi(resolved) ||
        resolved.path != '/api/v1/customer/account/profile-photo') {
      throw const FormatException('Untrusted private image URL.');
    }
    return api.requestBytes(
      resolved.path,
      queryParameters: resolved.queryParameters,
      lease: lease,
    );
  }

  @override
  Future<CustomerAccount> uploadPhoto(
    SessionLease lease, {
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!validProfilePhoto(
      length: bytes.lengthInBytes,
      filename: filename,
      mimeType: mimeType,
    )) {
      throw const ApiFailure(FailureKind.decode);
    }
    final response = await api.uploadBytes(
      'customer/account/profile-photo',
      fieldName: 'photo',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      lease: lease,
      onSendProgress: onProgress,
    );
    return ProfileMutation.parse(response).account;
  }

  @override
  Future<CustomerAccount> removePhoto(SessionLease lease) async {
    final response = await api.request(
      'DELETE',
      'customer/account/profile-photo',
      lease: lease,
    );
    return ProfileMutation.parse(response).account;
  }

  @override
  Future<PromotionPreference> promotionPreference(SessionLease lease) async {
    final response = await api.request(
      'GET',
      'customer/account/notification-preferences',
      lease: lease,
    );
    return PromotionPreference.parse(Wire(response).object('data'));
  }

  @override
  Future<PromotionPreference> setPromotionPreference(
    SessionLease lease,
    bool optedIn,
  ) async {
    final response = await api.request(
      'PATCH',
      'customer/account/notification-preferences',
      body: {'promotional_in_app_opted_in': optedIn},
      lease: lease,
    );
    return PromotionPreference.parse(Wire(response).object('data'));
  }
}
