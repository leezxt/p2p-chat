/// 應用層例外基底。在信任邊界（使用者輸入、檔案、網路、DB）擲出，
/// 帶可讀訊息與可選底層原因，方便統一處理與記錄（不含敏感資料）。
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AppException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// 資料庫相關錯誤。
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

/// 模組生命週期相關錯誤。
class ModuleException extends AppException {
  const ModuleException(super.message, {super.cause});
}
