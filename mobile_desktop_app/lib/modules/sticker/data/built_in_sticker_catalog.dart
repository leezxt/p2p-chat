import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../domain/sticker_pack_manifest.dart';

class BuiltInStickerCatalog {
  BuiltInStickerCatalog({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _manifestPaths = [
    'assets/stickers/simple_communication/manifest.json',
  ];

  final AssetBundle _bundle;
  final Map<String, StickerPackManifest> _packs = {};

  List<StickerPackManifest> get packs => List.unmodifiable(_packs.values);

  Future<void> load() async {
    final loaded = <String, StickerPackManifest>{};
    for (final path in _manifestPaths) {
      final raw = await _bundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid built-in sticker manifest.');
      }
      final manifest = StickerPackManifest.fromJson(decoded);
      if (loaded.containsKey(manifest.packId)) {
        throw const FormatException('Duplicate built-in sticker pack.');
      }
      for (final sticker in manifest.stickers) {
        final data = await _bundle.load(sticker.path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length != sticker.bytes ||
            sha256.convert(bytes).toString() != sticker.sha256) {
          throw const FormatException(
            'Built-in sticker asset integrity check failed.',
          );
        }
      }
      loaded[manifest.packId] = manifest;
    }
    _packs
      ..clear()
      ..addAll(loaded);
  }

  StickerAsset? resolve(String packId, String stickerId) {
    final pack = _packs[packId];
    if (pack == null) return null;
    for (final sticker in pack.stickers) {
      if (sticker.id == stickerId) return sticker;
    }
    return null;
  }
}
