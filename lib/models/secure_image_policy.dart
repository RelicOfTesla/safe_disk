import 'dart:typed_data';
import 'dart:ui' as ui;

const int kMaxSecureImageEncodedBytes = 64 * 1024 * 1024;
const int kMaxSecureImageDecodedPixels = 100 * 1000 * 1000;
const Set<String> kSupportedImageFormats = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'bmp',
  'webp',
};

bool isSupportedImageFormat(String? extension) {
  if (extension == null) return false;
  return kSupportedImageFormats.contains(extension.toLowerCase());
}

enum SecureImagePolicyViolation {
  encodedDataTooLarge,
  emptyContent,
  invalidDimensions,
  decodedPixelsTooLarge,
  invalidOrUnsupportedContent,
}

class SecureImagePolicyException implements Exception {
  const SecureImagePolicyException(this.violation, {this.limit});

  final SecureImagePolicyViolation violation;
  final int? limit;

  @override
  String toString() => 'secure-image-policy:${violation.name}';
}

class SecureImageMetadata {
  const SecureImageMetadata({
    required this.width,
    required this.height,
    required this.frameCount,
  });

  final int width;
  final int height;
  final int frameCount;

  int get pixelCount => width * height;
  bool get isAnimated => frameCount > 1;
}

typedef SecureImageInspector = Future<SecureImageMetadata> Function(
  Uint8List data, {
  int maxBytes,
  int maxPixels,
});

void validateSecureImageEncodedSize(
  int? size, {
  int maxBytes = kMaxSecureImageEncodedBytes,
}) {
  if (size != null && size > maxBytes) {
    throw SecureImagePolicyException(
      SecureImagePolicyViolation.encodedDataTooLarge,
      limit: maxBytes,
    );
  }
}

Future<SecureImageMetadata> inspectSecureImage(
  Uint8List data, {
  int maxBytes = kMaxSecureImageEncodedBytes,
  int maxPixels = kMaxSecureImageDecodedPixels,
}) async {
  if (data.isEmpty) {
    throw const SecureImagePolicyException(
      SecureImagePolicyViolation.emptyContent,
    );
  }
  validateSecureImageEncodedSize(data.length, maxBytes: maxBytes);

  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(data);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0) {
      throw const SecureImagePolicyException(
        SecureImagePolicyViolation.invalidDimensions,
      );
    }
    if (width > maxPixels ~/ height) {
      throw SecureImagePolicyException(
        SecureImagePolicyViolation.decodedPixelsTooLarge,
        limit: maxPixels,
      );
    }
    codec = await descriptor.instantiateCodec();
    return SecureImageMetadata(
      width: width,
      height: height,
      frameCount: codec.frameCount,
    );
  } on SecureImagePolicyException {
    rethrow;
  } catch (_) {
    throw const SecureImagePolicyException(
      SecureImagePolicyViolation.invalidOrUnsupportedContent,
    );
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

String formatImageByteLimit(int bytes) {
  if (bytes % (1024 * 1024) == 0) {
    return '${bytes ~/ (1024 * 1024)} MiB';
  }
  if (bytes % 1024 == 0) return '${bytes ~/ 1024} KiB';
  return '$bytes B';
}

String formatImagePixelLimit(int pixels) {
  if (pixels % 1000000 == 0) return '${pixels ~/ 1000000} MP';
  return '$pixels px';
}
