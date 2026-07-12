import 'package:uuid/uuid.dart';

/// 統一 ID 產生器。以前綴標示 ID 種類，方便除錯與日誌辨識。
class IdGenerator {
  IdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  String message() => 'msg_${_uuid.v4()}';
  String conversation() => 'conv_${_uuid.v4()}';
  String user() => 'user_${_uuid.v4()}';
  String device() => 'device_${_uuid.v4()}';

  String raw() => _uuid.v4();
}
