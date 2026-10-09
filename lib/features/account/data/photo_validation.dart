import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_dimensions.dart';

class BuyerImageValidationException extends FormatException {
  const BuyerImageValidationException(super.message);
}

const profilePhotoLimit = 10485760;
const profilePhotoFormats = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

bool validProfilePhoto({
  required int length,
  required String filename,
  required String mimeType,
}) =>
    length > 0 &&
    length < profilePhotoLimit &&
    filename.split('.').length == 2 &&
    filename.split('.').first.trim().isNotEmpty &&
    !RegExp(r'[\x00-\x1f\x7f/\\]').hasMatch(filename) &&
    profilePhotoFormats[filename.split('.').last.toLowerCase()] ==
        mimeType.toLowerCase();

/// Validate content before retaining a preview. Laravel rechecks all hints.
Future<void> validateBuyerImage(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
  bool review = false,
}) async {
  if (!validProfilePhoto(
    length: bytes.lengthInBytes,
    filename: filename,
    mimeType: mimeType,
  )) {
    throw const BuyerImageValidationException(
      'Choose JPEG, PNG or WebP under 10 MiB with one filename extension.',
    );
  }
  bool starts(List<int> signature, [int offset = 0]) =>
      bytes.length >= offset + signature.length &&
      List.generate(
        signature.length,
        (i) => bytes[offset + i] == signature[i],
      ).every((e) => e);
  final actualType = starts([137, 80, 78, 71, 13, 10, 26, 10])
      ? 'image/png'
      : starts([255, 216, 255])
      ? 'image/jpeg'
      : starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8)
      ? 'image/webp'
      : null;
  if (actualType != mimeType.toLowerCase()) {
    throw const BuyerImageValidationException(
      'The image contents do not match its file type. Choose another photo.',
    );
  }
  if (review) {
    final dimensions = buyerImageDimensions(bytes, actualType!);
    if (dimensions.width > 8000 ||
        dimensions.height > 8000 ||
        dimensions.width * dimensions.height > 40000000) {
      throw const BuyerImageValidationException(
        'Use images with edges up to 8,000 pixels and at most 40 million pixels.',
      );
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec(targetWidth: 1, targetHeight: 1);
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
