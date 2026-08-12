import 'sticker_pack_manifest.dart';

class StickerArchiveEntry {
  const StickerArchiveEntry({
    required this.path,
    required this.uncompressedBytes,
    this.isFile = true,
    this.isLink = false,
  });

  final String path;
  final int uncompressedBytes;
  final bool isFile;
  final bool isLink;
}

class StickerArchiveValidator {
  const StickerArchiveValidator();

  void validate(
    StickerPackManifest manifest,
    Iterable<StickerArchiveEntry> entries,
  ) {
    final files = <String, StickerArchiveEntry>{};
    var totalBytes = 0;
    for (final entry in entries) {
      if (!_safeArchivePath(entry.path) ||
          entry.isLink ||
          !entry.isFile ||
          entry.uncompressedBytes <= 0 ||
          entry.uncompressedBytes > StickerPackManifest.maxStickerBytes ||
          files.containsKey(entry.path)) {
        throw const FormatException('Unsafe sticker archive entry.');
      }
      totalBytes += entry.uncompressedBytes;
      if (totalBytes > StickerPackManifest.maxPackBytes) {
        throw const FormatException('Sticker archive is too large.');
      }
      files[entry.path] = entry;
    }
    final expected = manifest.stickers.map((asset) => asset.path).toSet();
    if (files.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(files.keys.toSet()).isNotEmpty) {
      throw const FormatException(
          'Sticker archive files do not match manifest.');
    }
    for (final asset in manifest.stickers) {
      if (files[asset.path]!.uncompressedBytes != asset.bytes) {
        throw const FormatException(
            'Sticker asset size does not match manifest.');
      }
    }
  }

  bool _safeArchivePath(String path) =>
      path.startsWith('assets/') &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path.contains(':') &&
      path.split('/').every(
            (part) => part.isNotEmpty && part != '.' && part != '..',
          );
}
