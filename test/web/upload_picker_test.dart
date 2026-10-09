@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_validation.dart';

import '../support/image_samples.dart';

class BrowserImagePicker extends ImagePicker {
  XFile? selection;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => selection;
  @override
  Future<LostDataResponse> retrieveLostData() =>
      throw StateError('Native recovery must not run in browser');
}

void main() {
  test('browser Blob-backed XFile uses bounded bytes and handles dismissal/invalid content', () async {
    final picker = BrowserImagePicker();
    final adapter = PhotoPickerAdapter(picker: picker);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    );
    picker.selection = XFile.fromData(
      bytes,
      name: 'photo.png',
      mimeType: 'image/png',
    );
    final selected = await adapter.pick(review: true);
    expect(selected!.bytes, bytes);
    await validateBuyerImage(
      selected.bytes,
      filename: selected.filename,
      mimeType: selected.mimeType,
      review: true,
    );
    expect(selected.filename, 'photo.png');
    expect(await adapter.recoverInterruptedSelection(), PickerRecovery.none);
    picker.selection = null;
    expect(await adapter.pick(), isNull);
    picker.selection = XFile.fromData(
      bytes,
      name: 'photo.jpg',
      mimeType: 'image/jpeg',
    );
    await expectLater(adapter.pick(), throwsFormatException);
  });
  test('browser Review checks handle JPEG and each WebP encoding without descriptor dimension getters', () async {
    for (final sample in buyerImageSamples) {
      final type = sample['mimeType']!;
      await validateBuyerImage(
        base64Decode(sample['bytes']!),
        filename: type == 'image/jpeg' ? 'sample.jpg' : 'sample.webp',
        mimeType: type,
        review: true,
      );
    }
  });
}
