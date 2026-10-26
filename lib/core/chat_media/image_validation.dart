import 'dart:typed_data';

/// Inspect bounded image headers before decoding; the API validates content again.
bool validChatImage(Uint8List bytes, String filename, String mime) {
  final parts = filename.split('.');
  if (bytes.isEmpty || bytes.length > 8000000 || parts.length != 2) {
    return false;
  }
  final extension = parts.last.toLowerCase();
  if (mime == 'image/png' && extension != 'png' ||
      mime == 'image/jpeg' && !['jpg', 'jpeg'].contains(extension)) {
    return false;
  }
  int u16(int i) => bytes[i] * 256 + bytes[i + 1];
  int u32(int i) => u16(i) * 65536 + u16(i + 2);
  bool size(int w, int h) =>
      w > 0 && h > 0 && w <= 4096 && h <= 4096 && w * h <= 8000000;
  if (mime == 'image/png') {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    return bytes.length >= 24 &&
        List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v) &&
        u32(8) == 13 &&
        u32(12) == 0x49484452 &&
        size(u32(16), u32(20));
  }
  if (mime != 'image/jpeg' || bytes.length < 4 || u16(0) != 0xffd8) {
    return false;
  }
  var offset = 2;
  while (offset + 1 < bytes.length) {
    if (bytes[offset++] != 255) return false;
    while (offset < bytes.length && bytes[offset] == 255) {
      offset++;
    }
    if (offset >= bytes.length) return false;
    final marker = bytes[offset++];
    if (marker == 0xda || marker == 0xd9) return false;
    if (marker == 1 || marker >= 0xd0 && marker <= 0xd8) continue;
    if (offset + 2 > bytes.length) return false;
    final length = u16(offset);
    if (length < 2 || offset + length > bytes.length) return false;
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
      return length >= 8 && size(u16(offset + 5), u16(offset + 3));
    }
    offset += length;
  }
  return false;
}
