import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/chat_media/image_validation.dart';

Uint8List png(int width, int height, {int bytes = 24}) {
  final data = Uint8List(bytes);
  data.setAll(0, [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
  ]);
  final view = ByteData.sublistView(data);
  view.setUint32(16, width);
  view.setUint32(20, height);
  return data;
}

void main() {
  for (final size in [7999999, 8000000, 8000001]) {
    test(
      'inclusive 8 MB boundary $size',
      () => expect(
        validChatImage(png(8, 8, bytes: size), 'photo.png', 'image/png'),
        size <= 8000000,
      ),
    );
  }
  for (final dimensions in [
    (4096, 1953, true),
    (4097, 1, false),
    (4000, 2000, true),
    (4000, 2001, false),
    (0, 8, false),
  ]) {
    test(
      'pixel bounds $dimensions',
      () => expect(
        validChatImage(
          png(dimensions.$1, dimensions.$2),
          'photo.png',
          'image/png',
        ),
        dimensions.$3,
      ),
    );
  }
  test('new WebP and mismatched, ambiguous and malformed files rejected', () {
    final image = png(8, 8);
    expect(validChatImage(image, 'photo.webp', 'image/webp'), false);
    expect(validChatImage(image, 'photo.jpg', 'image/png'), false);
    expect(validChatImage(image, 'photo.png.exe', 'image/png'), false);
    expect(validChatImage(Uint8List(3), 'photo.png', 'image/png'), false);
    expect(validChatImage(Uint8List(0), 'photo.jpg', 'image/jpeg'), false);
  });
  test('JPEG dimensions and corrupt segment bounds', () {
    final jpeg = Uint8List.fromList([
      255,
      216,
      255,
      192,
      0,
      8,
      8,
      0,
      8,
      0,
      8,
      1,
    ]);
    expect(validChatImage(jpeg, 'photo.JPG', 'image/jpeg'), true);
    jpeg[7] = 17;
    expect(validChatImage(jpeg, 'photo.jpg', 'image/jpeg'), false);
    jpeg[4] = 255;
    expect(validChatImage(jpeg, 'photo.jpg', 'image/jpeg'), false);
  });
}
