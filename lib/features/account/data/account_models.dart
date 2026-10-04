import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';
import '../../auth/data/auth_models.dart';

class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.profile,
    required this.security,
  });
  final String id, email, role, status;
  final CustomerProfile profile;
  final AccountSecurity security;

  factory CustomerAccount.parse(Object? json) {
    final wire = Wire(json);
    return CustomerAccount(
      id: wire.uuid('id'),
      email: wire.string('email'),
      role: wire.string('role'),
      status: wire.string('status'),
      profile: CustomerProfile.parse(wire.object('profile')),
      security: AccountSecurity.parse(wire.object('security')),
    );
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.contactNumber,
    required this.sex,
    required this.birthDate,
    required this.age,
    required this.profilePhotoUrl,
  });
  final String? firstName, middleName, lastName, contactNumber, sex;
  final String? birthDate;
  final int? age;
  final String? profilePhotoUrl;

  factory CustomerProfile.parse(Object? json) {
    final wire = Wire(json);
    final date = wire.nullableString('birthDate');
    if (date != null &&
        (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
            DateTime.tryParse(date)?.toIso8601String().substring(0, 10) !=
                date)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return CustomerProfile(
      firstName: wire.nullableString('firstName'),
      middleName: wire.nullableString('middleName'),
      lastName: wire.nullableString('lastName'),
      contactNumber: wire.nullableString('contactNumber'),
      sex: wire.nullableString('sex'),
      birthDate: date,
      age: wire.nullableInt('age'),
      profilePhotoUrl: wire.nullableString('profilePhotoUrl'),
    );
  }
}

class AccountSecurity {
  const AccountSecurity({
    required this.emailEditable,
    required this.passwordChangeRequiresCurrentPassword,
  });
  final bool emailEditable, passwordChangeRequiresCurrentPassword;

  factory AccountSecurity.parse(Object? json) {
    final wire = Wire(json);
    return AccountSecurity(
      emailEditable: wire.boolean('emailEditable'),
      passwordChangeRequiresCurrentPassword: wire.boolean(
        'passwordChangeRequiresCurrentPassword',
      ),
    );
  }
}

class PromotionPreference {
  const PromotionPreference({required this.optedIn, required this.optedInAt});
  final bool optedIn;
  final DateTime? optedInAt;

  factory PromotionPreference.parse(Object? json) {
    final wire = Wire(json);
    final date = wire.timestamp('promotional_in_app_opted_in_at');
    return PromotionPreference(
      optedIn: wire.boolean('promotional_in_app_opted_in'),
      optedInAt: date,
    );
  }
}

class ProfileInput {
  const ProfileInput({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.contactNumber,
    required this.sex,
    required this.birthDate,
  });
  final String firstName, middleName, lastName, contactNumber, sex, birthDate;
  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'middle_name': middleName.trim().isEmpty ? null : middleName.trim(),
    'last_name': lastName.trim(),
    'contact_number': contactNumber.trim(),
    'sex': sex,
    'birth_date': birthDate,
  };
}

class ProfileMutation {
  const ProfileMutation({
    required this.message,
    required this.account,
    required this.customer,
  });
  final String message;
  final CustomerAccount account;
  final CustomerIdentity customer;

  factory ProfileMutation.parse(Object? json) {
    final wire = Wire(json);
    return ProfileMutation(
      message: wire.string('message'),
      account: CustomerAccount.parse(wire.object('account')),
      customer: CustomerIdentity.parse(wire.object('customer')),
    );
  }
}
