import 'dart:typed_data';

/// Bounded header inspection before preview decoding. Server validation is authoritative.
/// Encoded ImageDescriptor dimensions are unavailable on Flutter web.
({int width, int height}) buyerImageDimensions(Uint8List bytes, String type) {
  int byte(int offset) {
    if (offset < 0 || offset >= bytes.length) {
      throw const FormatException('Incomplete image header.');
    }
    return bytes[offset];
  }

  int big16(int offset) => byte(offset) * 256 + byte(offset + 1);
  int big32(int offset) => big16(offset) * 65536 + big16(offset + 2);
  int little16(int offset) => byte(offset) + byte(offset + 1) * 256;
  int little24(int offset) => little16(offset) + byte(offset + 2) * 65536;
  int little32(int offset) => little16(offset) + little16(offset + 2) * 65536;
  bool matches(int offset, List<int> value) =>
      offset + value.length <= bytes.length &&
      List.generate(
        value.length,
        (i) => bytes[offset + i] == value[i],
      ).every((e) => e);
  ({int width, int height}) size(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw const FormatException('Invalid image dimensions.');
    }
    return (width: width, height: height);
  }

  switch (type.toLowerCase()) {
    case 'image/png':
      if (big32(8) != 13 || !matches(12, [73, 72, 68, 82])) break;
      return size(big32(16), big32(20));
    case 'image/jpeg':
      var offset = 2;
      while (offset < bytes.length) {
        if (byte(offset++) != 255) break;
        while (offset < bytes.length && byte(offset) == 255) {
          offset++;
        }
        final marker = byte(offset++);
        if (marker == 0xda || marker == 0xd9) break;
        if (marker == 0xd8 || marker == 1 || marker >= 0xd0 && marker <= 0xd7) {
          continue;
        }
        final length = big16(offset);
        if (length < 2 || offset + length > bytes.length) break;
        if (const {
          0xc0,
          0xc1,
          0xc2,
          0xc3,
          0xc5,
          0xc6,
          0xc7,
          0xc9,
          0xca,
          0xcb,
          0xcd,
          0xce,
          0xcf,
        }.contains(marker)) {
          if (length < 8) break;
          return size(big16(offset + 5), big16(offset + 3));
        }
        offset += length;
      }
    case 'image/webp':
      var offset = 12;
      while (offset + 8 <= bytes.length) {
        final length = little32(offset + 4), data = offset + 8;
        if (data + length > bytes.length) break;
        if (matches(offset, [86, 80, 56, 88]) && length >= 10) {
          return size(little24(data + 4) + 1, little24(data + 7) + 1);
        }
        if (matches(offset, [86, 80, 56, 76]) &&
            length >= 5 &&
            byte(data) == 0x2f) {
          final bits = little32(data + 1);
          return size((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
        }
        if (matches(offset, [86, 80, 56, 32]) &&
            length >= 10 &&
            matches(data + 3, [0x9d, 1, 0x2a])) {
          return size(little16(data + 6) & 0x3fff, little16(data + 8) & 0x3fff);
        }
        offset = data + length + (length.isOdd ? 1 : 0);
      }
  }
  throw const FormatException('Image dimensions could not be read.');
}
