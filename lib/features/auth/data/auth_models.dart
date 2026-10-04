import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';

class CustomerIdentity {
  const CustomerIdentity({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.status,
  });
  factory CustomerIdentity.parse(Object? value) {
    final wire = Wire(value);
    return CustomerIdentity(
      id: wire.uuid('id'),
      displayName: wire.nullableString('displayName'),
      avatarUrl: wire.nullableString('avatarUrl'),
      role: wire.string('role'),
      status: wire.string('status'),
    );
  }
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final String status;
  bool get isActiveCustomer => role == 'customer' && status == 'active';
}

class LoginResult {
  LoginResult.parse(Object? value) {
    final wire = Wire(value);
    wire.string('message');
    customer = CustomerIdentity.parse(wire.field('customer'));
    token = wire.string('token');
    if (token.trim().isEmpty) throw const ApiFailure(FailureKind.decode);
  }
  late final CustomerIdentity customer;
  late final String token;
  @override
  String toString() => 'LoginResult';
}

class RegistrationResult {
  RegistrationResult.parse(Object? value) {
    final wire = Wire(value);
    wire.string('message');
    final customer = Wire(wire.field('customer'));
    id = customer.uuid('id');
    customer.string('email');
    if (customer.string('role') != 'customer' ||
        customer.string('status') != 'pending' ||
        wire.data.containsKey('token')) {
      throw const ApiFailure(FailureKind.decode);
    }
    final profile = Wire(customer.field('profile'));
    for (final key in [
      'first_name',
      'last_name',
      'middle_name',
      'contact_number',
      'sex',
      'birth_date',
    ]) {
      profile.nullableString(key);
    }
    // Validate the legacy wire field, but never retain or use a storage path.
    profile.nullableString('profile_photo_path');
  }
  late final String id;
}

class RegistrationInput {
  const RegistrationInput({
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.contactNumber,
    required this.sex,
    required this.birthDate,
    required this.email,
    required this.password,
    required this.confirmation,
  });
  final String firstName,
      lastName,
      contactNumber,
      sex,
      birthDate,
      email,
      password,
      confirmation;
  final String? middleName;
  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'middle_name': middleName?.trim().isEmpty == true
        ? null
        : middleName?.trim(),
    'contact_number': contactNumber.trim(),
    'sex': sex,
    'birth_date': birthDate,
    'email': normalizeEmail(email),
    'password': password,
    'password_confirmation': confirmation,
  };
  @override
  String toString() => 'RegistrationInput';
}

String normalizeEmail(String email) => email.trim().toLowerCase();
