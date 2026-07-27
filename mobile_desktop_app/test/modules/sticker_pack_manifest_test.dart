import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/sticker/domain/sticker_archive_validator.dart';
import 'package:p2p_chat_app/modules/sticker/domain/sticker_pack_manifest.dart';

void main() {
  test('accepts a bounded manifest with explicit license metadata', () {
    final manifest = StickerPackManifest.fromJson(_manifest());

    expect(manifest.packId, 'simple_shapes');
    expect(manifest.license.spdx, 'CC-BY-4.0');
    expect(manifest.names['zh_TW'], '簡單圖形');
  });

  test('rejects missing license, unknown fields, unsafe paths, and bad hashes',
      () {
    final missingLicense = _manifest()..remove('license');
    final unknown = _manifest()..['trackingUrl'] = 'https://tracker.invalid';
    final unsafe = _manifest();
    (unsafe['stickers'] as List).first['path'] = '../private.png';
    final badHash = _manifest();
    (badHash['stickers'] as List).first['sha256'] = 'not-a-hash';

    for (final value in [missingLicense, unknown, unsafe, badHash]) {
      expect(
        () => StickerPackManifest.fromJson(value),
        throwsFormatException,
      );
    }
  });

  test('rejects oversized stickers and duplicate sticker ids', () {
    final oversized = _manifest();
    (oversized['stickers'] as List).first['bytes'] =
        StickerPackManifest.maxStickerBytes + 1;
    final duplicate = _manifest();
    (duplicate['stickers'] as List).add(
      Map<String, Object?>.from(
        (duplicate['stickers'] as List).first as Map,
      ),
    );

    expect(
      () => StickerPackManifest.fromJson(oversized),
      throwsFormatException,
    );
    expect(
      () => StickerPackManifest.fromJson(duplicate),
      throwsFormatException,
    );
  });

  test(
      'archive validator blocks zip-slip, links, duplicates, and size mismatch',
      () {
    final manifest = StickerPackManifest.fromJson(_manifest());
    const validator = StickerArchiveValidator();
    validator.validate(manifest, const [
      StickerArchiveEntry(path: 'assets/hello.png', uncompressedBytes: 128),
    ]);

    for (final entries in [
      const [
        StickerArchiveEntry(path: '../hello.png', uncompressedBytes: 128),
      ],
      const [
        StickerArchiveEntry(
          path: 'assets/hello.png',
          uncompressedBytes: 128,
          isLink: true,
        ),
      ],
      const [
        StickerArchiveEntry(path: 'assets/hello.png', uncompressedBytes: 128),
        StickerArchiveEntry(path: 'assets/hello.png', uncompressedBytes: 128),
      ],
      const [
        StickerArchiveEntry(path: 'assets/hello.png', uncompressedBytes: 127),
      ],
    ]) {
      expect(
          () => validator.validate(manifest, entries), throwsFormatException);
    }
  });
}

Map<String, Object?> _manifest() => {
      'schemaVersion': 1,
      'packId': 'simple_shapes',
      'names': {
        'en': 'Simple Shapes',
        'zh_TW': '簡單圖形',
      },
      'license': {
        'spdx': 'CC-BY-4.0',
        'copyright': '2026 leezxt',
        'sourceUrl': 'https://example.com/stickers',
      },
      'stickers': [
        {
          'id': 'hello',
          'path': 'assets/hello.png',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'bytes': 128,
          'width': 128,
          'height': 128,
        },
      ],
    };
