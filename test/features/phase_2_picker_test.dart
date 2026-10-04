import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';

class SyntheticPicker extends ImagePicker {
  XFile? selection;
  LostDataResponse lost = LostDataResponse.empty();
  bool fullMetadata = true;
  int selections = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    selections++;
    fullMetadata = requestFullMetadata;
    return selection;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => lost;
}

void main() {
  test('picker uses selected bytes, requests minimal metadata and handles cancellation', () async {
    final picker = SyntheticPicker();
    final adapter = PhotoPickerAdapter(picker: picker);
    expect(await adapter.pick(), isNull);
    picker.selection = XFile.fromData(
      Uint8List.fromList([0, 128, 255]),
      path: 'synthetic.png',
      name: 'synthetic.png',
      mimeType: 'image/png',
    );
    final result = await adapter.pick();
    expect(result!.bytes, [0, 128, 255]);
    expect(result.filename, 'synthetic.png');
    expect(result.mimeType, 'image/png');
    expect(picker.fullMetadata, isFalse);
  });
  test('interrupted picker recovery discards files and requires a deliberate new selection', () async {
    final picker = SyntheticPicker()
      ..lost = LostDataResponse(
        file: XFile.fromData(
          Uint8List(10),
          path: 'lost.png',
          mimeType: 'image/png',
        ),
      );
    final adapter = PhotoPickerAdapter(picker: picker);
    expect(await adapter.hasInterruptedSelection(), isTrue);
    expect(picker.selections, 0);
  });
  test(
    'picker rejects the exact ten MiB boundary before reading bytes',
    () async {
      final picker = SyntheticPicker()
        ..selection = XFile.fromData(
          Uint8List(0),
          path: 'synthetic.png',
          mimeType: 'image/png',
          length: 10485760,
        );
      await expectLater(
        PhotoPickerAdapter(picker: picker).pick(),
        throwsFormatException,
      );
    },
  );
}
