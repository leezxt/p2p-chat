import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';

/// 實際檔案 transport、相機與麥克風尚未接入；保留模組邊界供後續按需啟動。
class AttachmentModule extends AppModule {
  @override
  String get name => 'attachment';

  @override
  Future<void> init(ModuleContext context) async {}

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
