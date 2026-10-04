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
    !RegExp(r'[\x00-\x1f\x7f/\\]').hasMatch(filename) &&
    profilePhotoFormats[filename.split('.').last.toLowerCase()] ==
        mimeType.toLowerCase();
