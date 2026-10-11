import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/account/data/image_dimensions.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_validation.dart';

import '../support/image_samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in buyerImageSamples) {
    test(
      '${sample['name']} dimensions match a decodable Review image',
      () async {
        final bytes = base64Decode(sample['bytes']!);
        final type = sample['mimeType']!;
        expect(buyerImageDimensions(bytes, type), (width: 32, height: 24));
        await validateBuyerImage(
          bytes,
          filename: type == 'image/jpeg' ? 'sample.jpg' : 'sample.webp',
          mimeType: type,
          review: true,
        );
        for (final length in [0, 8, 12]) {
          expect(
            () => buyerImageDimensions(bytes.sublist(0, length), type),
            throwsFormatException,
          );
        }
      },
    );
  }
  test('40 million pixel ceiling is checked before preview decoding', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    );
    final data = ByteData.sublistView(bytes);
    data.setUint32(16, 7000);
    data.setUint32(20, 6000);
    expect(buyerImageDimensions(bytes, 'image/png'), (
      width: 7000,
      height: 6000,
    ));
    await expectLater(
      validateBuyerImage(
        bytes,
        filename: 'wide.png',
        mimeType: 'image/png',
        review: true,
      ),
      throwsA(
        isA<BuyerImageValidationException>().having(
          (e) => e.message,
          'message',
          contains('40 million'),
        ),
      ),
    );
  });
}
