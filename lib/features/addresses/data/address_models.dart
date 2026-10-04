import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';

class BuyerAddress {
  const BuyerAddress({
    required this.id,
    required this.type,
    required this.label,
    required this.recipientName,
    required this.contactNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });
  final String id, type, recipientName, contactNumber, addressLine1;
  final String? label, addressLine2;
  final String barangay,
      cityMunicipality,
      province,
      region,
      postalCode,
      country;
  final double? latitude, longitude;
  final bool isDefault;

  factory BuyerAddress.parse(Object? json) {
    final wire = Wire(json);
    final latitude = wire.nullableCoordinate('latitude');
    final longitude = wire.nullableCoordinate('longitude');
    if ((latitude == null) != (longitude == null) ||
        latitude != null && (latitude < -90 || latitude > 90) ||
        longitude != null && (longitude < -180 || longitude > 180)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return BuyerAddress(
      id: wire.uuid('id'),
      type: wire.string('type'),
      label: wire.nullableString('label'),
      recipientName: wire.string('recipientName'),
      contactNumber: wire.string('contactNumber'),
      addressLine1: wire.string('addressLine1'),
      addressLine2: wire.nullableString('addressLine2'),
      barangay: wire.string('barangay'),
      cityMunicipality: wire.string('cityMunicipality'),
      province: wire.string('province'),
      region: wire.string('region'),
      postalCode: wire.string('postalCode'),
      country: wire.string('country'),
      latitude: latitude,
      longitude: longitude,
      isDefault: wire.boolean('isDefault'),
    );
  }
}

class AddressInput {
  const AddressInput({
    required this.type,
    required this.label,
    required this.recipientName,
    required this.contactNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });
  final String type;
  final String? label;
  final String recipientName, contactNumber, addressLine1;
  final String? addressLine2;
  final String barangay,
      cityMunicipality,
      province,
      region,
      postalCode,
      country;
  final double? latitude, longitude;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    if ((latitude == null) != (longitude == null) ||
        latitude != null &&
            (!latitude!.isFinite || latitude! < -90 || latitude! > 90) ||
        longitude != null &&
            (!longitude!.isFinite || longitude! < -180 || longitude! > 180)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return {
      'type': type,
      'label': _nullable(label),
      'recipient_name': recipientName.trim(),
      'contact_number': contactNumber.trim(),
      'address_line_1': addressLine1.trim(),
      'address_line_2': _nullable(addressLine2),
      'barangay': barangay.trim(),
      'city_municipality': cityMunicipality.trim(),
      'province': province.trim(),
      'region': region.trim(),
      'postal_code': postalCode.trim(),
      'country': country.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }

  static String? _nullable(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
