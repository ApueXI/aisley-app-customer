import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_validation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';

class SyntheticPicker extends ImagePicker {
  XFile? selection;
  LostDataResponse lost = LostDataResponse.empty();
  bool fullMetadata = true;
  int selections = 0, recoveries = 0;
  Future<XFile?>? pending;
  bool failRecovery = false;
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
    return pending ?? selection;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveries++;
    if (failRecovery) throw PlatformException(code: 'synthetic');
    return lost;
  }
}

class StreamFile extends XFile {
  StreamFile(
    this.content, {
    this.reportedLength,
    this.displayName = 'photo.png',
    this.type = 'image/png',
  }) : super('do-not-read-native-path');
  final Uint8List content;
  final int? reportedLength;
  final String displayName, type;
  int streams = 0;
  @override
  String get name => displayName;
  @override
  String? get mimeType => type;
  @override
  Future<int> length() async => reportedLength ?? content.length;
  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Unbounded read must not be used');
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    streams++;
    yield content;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
  );
  test('picker uses selected bytes, requests minimal metadata and handles cancellation', () async {
    final picker = SyntheticPicker();
    final adapter = PhotoPickerAdapter(picker: picker);
    expect(await adapter.pick(), isNull);
    picker.selection = XFile.fromData(
      png,
      path: 'synthetic.png',
      name: 'synthetic.png',
      mimeType: 'image/png',
    );
    final result = await adapter.pick();
    expect(result!.bytes, png);
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
    final adapter = PhotoPickerAdapter(picker: picker, nativeRecovery: true);
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
  test(
    'bounded stream reads ignore OS paths and recheck actual length',
    () async {
      final file = StreamFile(png);
      final picker = SyntheticPicker()..selection = file;
      final result = await PhotoPickerAdapter(picker: picker).pick();
      expect(result!.bytes, png);
      expect(file.streams, 1);
      picker.selection = StreamFile(png, reportedLength: 1);
      await expectLater(
        PhotoPickerAdapter(picker: picker).pick(),
        throwsFormatException,
      );
      picker.selection = StreamFile(Uint8List(10485760), reportedLength: 1);
      await expectLater(
        PhotoPickerAdapter(picker: picker).pick(),
        throwsFormatException,
      );
    },
  );
  test('invalid metadata is rejected before a stream is opened', () async {
    for (final file in [
      StreamFile(png, displayName: 'photo.png.exe'),
      StreamFile(png, displayName: 'photo.heic', type: 'image/heic'),
      StreamFile(png, displayName: '../photo.png'),
      StreamFile(png, type: 'image/jpeg'),
      StreamFile(png, reportedLength: 10485760),
      StreamFile(Uint8List(0)),
    ]) {
      await expectLater(
        PhotoPickerAdapter(picker: SyntheticPicker()..selection = file).pick(),
        throwsFormatException,
      );
      expect(file.streams, 0);
    }
  });
  test('mislabeled and corrupt content never become a preview', () async {
    for (final file in [
      StreamFile(png, displayName: 'photo.jpg', type: 'image/jpeg'),
      StreamFile(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
      StreamFile(Uint8List.fromList([1, 2, 3])),
    ]) {
      await expectLater(
        PhotoPickerAdapter(picker: SyntheticPicker()..selection = file).pick(),
        throwsA(anything),
      );
    }
  });
  test('Review pixel caps are enforced before decoding a preview', () async {
    final oversized = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAH0EAAAABCAYAAAC8ofMkAAAANklEQVR4nO3BMQEAAADCoPVP7WsIoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADOAH0FAAE/0qTtAAAAAElFTkSuQmCC',
    );
    await expectLater(
      validateBuyerImage(
        oversized,
        filename: 'wide.png',
        mimeType: 'image/png',
        review: true,
      ),
      throwsA(isA<BuyerImageValidationException>()),
    );
    await validateBuyerImage(
      oversized,
      filename: 'wide.png',
      mimeType: 'image/png',
    );
  });
  test(
    'native recovery is drained once; failures are visible and web skips it',
    () async {
      final picker = SyntheticPicker()..failRecovery = true;
      final adapter = PhotoPickerAdapter(picker: picker, nativeRecovery: true);
      expect(
        await adapter.recoverInterruptedSelection(),
        PickerRecovery.failed,
      );
      expect(
        await adapter.recoverInterruptedSelection(),
        PickerRecovery.failed,
      );
      expect(picker.recoveries, 1);
      final web = PhotoPickerAdapter(picker: picker, nativeRecovery: false);
      expect(await web.recoverInterruptedSelection(), PickerRecovery.none);
      expect(picker.recoveries, 1);
    },
  );
  test(
    'overlapping picker calls never launch another native selection',
    () async {
      final result = Completer<XFile?>();
      final picker = SyntheticPicker()..pending = result.future;
      final adapter = PhotoPickerAdapter(picker: picker);
      final first = adapter.pick();
      expect(await adapter.pick(), isNull);
      result.complete(null);
      expect(await first, isNull);
      expect(picker.selections, 1);
    },
  );
}
