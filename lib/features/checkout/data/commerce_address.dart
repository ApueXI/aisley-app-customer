import '../../../core/networking/wire.dart';
import '../../addresses/data/address_models.dart';

/// Immutable Order/quote address facts, separate from editable Address Book rows.
class CommerceAddress {
  CommerceAddress.parse(
    Object? json, {
    bool delivery = false,
    bool quote = false,
    bool batch = false,
  }) {
    final w = Wire(json);
    version = delivery ? w.positiveInt('version') : null;
    id = quote ? w.uuid('id') : null;
    label = quote ? w.nullableString('label') : null;
    recipient = w.string('recipientName');
    contact = w.string('contactNumber');
    line1 = w.string('addressLine1');
    line2 = w.nullableString('addressLine2');
    barangay = w.string('barangay');
    city = w.string('cityMunicipality');
    province = w.string('province');
    region = w.string('region');
    postalCode = w.string('postalCode');
    country = w.string('country');
    latitude = batch ? w.nullableCoordinate('latitude') : null;
    longitude = batch ? w.nullableCoordinate('longitude') : null;
  }
  late final int? version;
  late final String? id, label, line2;
  late final String recipient,
      contact,
      line1,
      barangay,
      city,
      province,
      region,
      postalCode,
      country;
  late final double? latitude, longitude;
  String get locationText => [
    line1,
    if (line2?.trim().isNotEmpty == true) line2!,
    barangay,
    city,
    province,
    region,
    postalCode,
    country,
  ].join(', ');

  /// G21: fail closed unless every required location field is verifiable and unchanged.
  bool permitsContactCorrection(BuyerAddress candidate) {
    if (!const ['shipping', 'both'].contains(candidate.type)) return false;
    final snapshot = [
      line1,
      barangay,
      city,
      province,
      region,
      postalCode,
      country,
    ];
    final replacement = [
      candidate.addressLine1,
      candidate.barangay,
      candidate.cityMunicipality,
      candidate.province,
      candidate.region,
      candidate.postalCode,
      candidate.country,
    ];
    for (var i = 0; i < snapshot.length; i++) {
      if (snapshot[i].trim().isEmpty ||
          replacement[i].trim().isEmpty ||
          snapshot[i].trim() != replacement[i].trim()) {
        return false;
      }
    }
    String? normalized(String? text) =>
        text == null || text.trim().isEmpty ? null : text.trim();
    return normalized(line2) == normalized(candidate.addressLine2) &&
        recipient.trim().isNotEmpty &&
        contact.trim().isNotEmpty &&
        candidate.recipientName.trim().isNotEmpty &&
        candidate.contactNumber.trim().isNotEmpty &&
        (recipient.trim() != candidate.recipientName.trim() ||
            contact.trim() != candidate.contactNumber.trim());
  }
}
