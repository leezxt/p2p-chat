class StickerPackManifest {
  const StickerPackManifest({
    required this.packId,
    required this.names,
    required this.license,
    required this.stickers,
  });

  static const int schemaVersion = 1;
  static const int maxStickerCount = 100;
  static const int maxStickerBytes = 512 * 1024;
  static const int maxPackBytes = 5 * 1024 * 1024;
  static const int maxDimension = 512;
  static final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _spdxPattern = RegExp(r'^[A-Za-z0-9.+-]{1,64}$');

  final String packId;
  final Map<String, String> names;
  final StickerLicense license;
  final List<StickerAsset> stickers;

  factory StickerPackManifest.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      const {'schemaVersion', 'packId', 'names', 'license', 'stickers'},
      'manifest',
    );
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported sticker manifest version.');
    }
    final packId = json['packId'];
    final names = json['names'];
    final license = json['license'];
    final stickers = json['stickers'];
    if (packId is! String ||
        !_idPattern.hasMatch(packId) ||
        names is! Map ||
        license is! Map ||
        stickers is! List ||
        stickers.isEmpty ||
        stickers.length > maxStickerCount) {
      throw const FormatException('Invalid sticker manifest values.');
    }
    final parsedNames = Map<String, Object?>.from(names);
    _requireExactKeys(parsedNames, const {'en', 'zh_TW'}, 'names');
    if (parsedNames.values.any(
      (value) => value is! String || value.trim().isEmpty || value.length > 80,
    )) {
      throw const FormatException('Invalid localized sticker pack name.');
    }
    final parsedStickers = stickers
        .map(
          (value) => StickerAsset.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList(growable: false);
    if (parsedStickers.map((asset) => asset.id).toSet().length !=
        parsedStickers.length) {
      throw const FormatException('Duplicate sticker id.');
    }
    final totalBytes = parsedStickers.fold<int>(
      0,
      (total, asset) => total + asset.bytes,
    );
    if (totalBytes > maxPackBytes) {
      throw const FormatException('Sticker pack is too large.');
    }
    return StickerPackManifest(
      packId: packId,
      names: parsedNames.cast<String, String>(),
      license: StickerLicense.fromJson(
        Map<String, Object?>.from(license),
      ),
      stickers: parsedStickers,
    );
  }
}

class StickerLicense {
  const StickerLicense({
    required this.spdx,
    required this.copyright,
    this.sourceUrl,
  });

  final String spdx;
  final String copyright;
  final String? sourceUrl;

  factory StickerLicense.fromJson(Map<String, Object?> json) {
    final allowed = {'spdx', 'copyright', 'sourceUrl'};
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        !json.containsKey('spdx') ||
        !json.containsKey('copyright')) {
      throw const FormatException('Invalid sticker license fields.');
    }
    final spdx = json['spdx'];
    final copyright = json['copyright'];
    final sourceUrl = json['sourceUrl'];
    final parsedUrl = sourceUrl == null ? null : Uri.tryParse('$sourceUrl');
    if (spdx is! String ||
        !StickerPackManifest._spdxPattern.hasMatch(spdx) ||
        copyright is! String ||
        copyright.trim().isEmpty ||
        copyright.length > 200 ||
        (sourceUrl != null &&
            (sourceUrl is! String ||
                parsedUrl == null ||
                parsedUrl.scheme != 'https' ||
                parsedUrl.host.isEmpty ||
                parsedUrl.hasFragment ||
                parsedUrl.hasQuery ||
                parsedUrl.userInfo.isNotEmpty))) {
      throw const FormatException('Invalid sticker license values.');
    }
    return StickerLicense(
      spdx: spdx,
      copyright: copyright,
      sourceUrl: sourceUrl as String?,
    );
  }
}

class StickerAsset {
  const StickerAsset({
    required this.id,
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String id;
  final String path;
  final String sha256;
  final int bytes;
  final int width;
  final int height;

  factory StickerAsset.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      const {'id', 'path', 'sha256', 'bytes', 'width', 'height'},
      'sticker',
    );
    final id = json['id'];
    final path = json['path'];
    final sha256 = json['sha256'];
    final bytes = json['bytes'];
    final width = json['width'];
    final height = json['height'];
    if (id is! String ||
        !StickerPackManifest._idPattern.hasMatch(id) ||
        path is! String ||
        !_isSafeAssetPath(path) ||
        sha256 is! String ||
        !StickerPackManifest._sha256Pattern.hasMatch(sha256) ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > StickerPackManifest.maxStickerBytes ||
        width is! int ||
        width <= 0 ||
        width > StickerPackManifest.maxDimension ||
        height is! int ||
        height <= 0 ||
        height > StickerPackManifest.maxDimension) {
      throw const FormatException('Invalid sticker asset.');
    }
    return StickerAsset(
      id: id,
      path: path,
      sha256: sha256,
      bytes: bytes,
      width: width,
      height: height,
    );
  }
}

bool _isSafeAssetPath(String value) {
  if (value.contains('\\') ||
      value.startsWith('/') ||
      value.contains(':') ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    return false;
  }
  final lower = value.toLowerCase();
  return value.startsWith('assets/') &&
      (lower.endsWith('.png') || lower.endsWith('.webp'));
}

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String label,
) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw FormatException('Invalid $label fields.');
  }
}
