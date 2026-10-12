import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_validation.dart';

class PickedBuyerImage {
  const PickedBuyerImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String filename, mimeType;
}

enum PickerRecovery { none, interrupted, failed }

class PhotoPickerAdapter {
  PhotoPickerAdapter({ImagePicker? picker, bool? nativeRecovery, this.maxBytes})
    : _picker = picker ?? ImagePicker(),
      _nativeRecovery =
          nativeRecovery ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final ImagePicker _picker;
  final int? maxBytes;
  final bool _nativeRecovery;
  bool _picking = false;
  Future<PickerRecovery>? _recovery;

  Future<PickedBuyerImage?> pick({bool review = false}) async {
    if (_picking) return null;
    _picking = true;
    try {
      // Drain native process-death files before starting a new intent.
      await recoverInterruptedSelection();
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final length = await file.length();
      final limit = maxBytes;
      if (limit != null && length > limit) {
        throw const BuyerImageValidationException(
          'Choose an image at most 8 MB (8,000,000 bytes).',
        );
      }
      final name = file.name;
      final mimeType = file.mimeType ?? _mimeFromName(name);
      if (!validProfilePhoto(
        length: length,
        filename: name,
        mimeType: mimeType,
      )) {
        throw const BuyerImageValidationException(
          'Choose JPEG, PNG or WebP under 10 MiB with one filename extension.',
        );
      }
      final builder = BytesBuilder(copy: false);
      // Bounded portable read, including browser Blob-backed XFiles.
      await for (final chunk in file.openRead(0, length)) {
        if (limit != null && builder.length + chunk.length > limit) {
          throw const BuyerImageValidationException(
            'Choose an image at most 8 MB (8,000,000 bytes).',
          );
        }
        if (builder.length + chunk.length >= profilePhotoLimit) {
          throw const BuyerImageValidationException(
            'Photo must be smaller than 10 MiB.',
          );
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length != length || await file.length() != length) {
        throw const BuyerImageValidationException(
          'The file changed while reading. Select it again.',
        );
      }
      await validateBuyerImage(
        bytes,
        filename: name,
        mimeType: mimeType,
        review: review,
      );
      return PickedBuyerImage(bytes: bytes, filename: name, mimeType: mimeType);
    } finally {
      _picking = false;
    }
  }

  /// Lost files have no proven Customer/form context. Never restore or upload them.
  Future<PickerRecovery> recoverInterruptedSelection() =>
      _recovery ??= _recover();

  Future<PickerRecovery> _recover() async {
    if (!_nativeRecovery) return PickerRecovery.none;
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.exception != null) return PickerRecovery.failed;
      return lost.isEmpty ? PickerRecovery.none : PickerRecovery.interrupted;
    } catch (_) {
      return PickerRecovery.failed;
    }
  }

  Future<bool> hasInterruptedSelection() async =>
      await recoverInterruptedSelection() == PickerRecovery.interrupted;

  String _mimeFromName(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'application/octet-stream',
      };
}
