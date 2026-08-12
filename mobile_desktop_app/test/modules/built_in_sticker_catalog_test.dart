import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/sticker/data/built_in_sticker_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in sticker manifest matches bundled asset hash and size',
      () async {
    final catalog = BuiltInStickerCatalog();

    await catalog.load();

    expect(catalog.packs, hasLength(1));
    expect(
      catalog.resolve('simple_communication', 'flutter')?.bytes,
      1443,
    );
    expect(catalog.resolve('unknown', 'flutter'), isNull);
  });
}
