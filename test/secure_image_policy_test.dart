import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/secure_image_policy.dart';

import 'support/image_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flutter codec probes every advertised image format', () async {
    for (final extension in imageFixtureExtensions) {
      final metadata = await inspectSecureImage(imageFixture(extension));
      expect(metadata.width, 2, reason: extension);
      expect(metadata.height, 3, reason: extension);
      expect(metadata.frameCount, extension == 'gif' ? 2 : 1,
          reason: extension);
    }
  });

  test('rejects encoded bytes, decoded pixels, and corrupt content', () async {
    final png = imageFixture('png');
    await expectLater(
      inspectSecureImage(png, maxBytes: png.length - 1),
      throwsA(
        isA<SecureImagePolicyException>().having(
          (error) => error.violation,
          'violation',
          SecureImagePolicyViolation.encodedDataTooLarge,
        ),
      ),
    );
    await expectLater(
      inspectSecureImage(png, maxPixels: 5),
      throwsA(
        isA<SecureImagePolicyException>().having(
          (error) => error.violation,
          'violation',
          SecureImagePolicyViolation.decodedPixelsTooLarge,
        ),
      ),
    );
    await expectLater(
      inspectSecureImage(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(
        isA<SecureImagePolicyException>().having(
          (error) => error.violation,
          'violation',
          SecureImagePolicyViolation.invalidOrUnsupportedContent,
        ),
      ),
    );
  });
}
