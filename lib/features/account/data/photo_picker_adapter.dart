import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedBuyerImage {
  const PickedBuyerImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String filename, mimeType;
}

class PhotoPickerAdapter {
  PhotoPickerAdapter({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<PickedBuyerImage?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() >= 10485760) {
      throw const FormatException('Photo must be smaller than 10 MiB.');
    }
    final bytes = await file.readAsBytes();
    final name = file.name;
    final mimeType = file.mimeType ?? _mimeFromName(name);
    return PickedBuyerImage(bytes: bytes, filename: name, mimeType: mimeType);
  }

  /// Lost picker files are not uploaded because a process restart cannot prove
  /// they belong to the current account/form. The screen asks the user to pick
  /// the file again after identity has been verified.
  Future<bool> hasInterruptedSelection() async {
    try {
      return !(await _picker.retrieveLostData()).isEmpty;
    } catch (_) {
      return false;
    }
  }

  String _mimeFromName(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'application/octet-stream',
      };
}
