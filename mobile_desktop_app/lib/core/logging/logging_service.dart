import 'dart:developer' as developer;

/// 日誌等級。
enum LogLevel { debug, info, warn, error }

class LogEntry {
  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  final LogLevel level;
  final String tag;
  final String message;
  final StackTrace? stackTrace;
}

typedef LogSink = void Function(LogEntry entry);

/// 分級日誌服務。統一由此輸出，不直接用 print（見 analysis_options）。
///
/// 預設走 dart:developer.log；正式版可替換為寫檔 / 上報，但**不得記錄**
/// 明文聊天內容、私鑰、金鑰等敏感資料（規格 §26、docs/security）。
class LoggingService {
  LoggingService({this.minLevel = LogLevel.debug, LogSink? sink})
      : _sink = sink;

  /// 低於此等級的訊息不輸出。正式版可設為 [LogLevel.info] 或更高。
  LogLevel minLevel;
  final LogSink? _sink;

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warn(String tag, String message) => _log(LogLevel.warn, tag, message);

  void error(String tag, String message, [StackTrace? stackTrace]) =>
      _log(LogLevel.error, tag, message, stackTrace);

  void _log(LogLevel level, String tag, String message, [StackTrace? st]) {
    if (level.index < minLevel.index) return;
    final safeMessage = _redact(message);
    final safeStackTrace =
        st == null ? null : StackTrace.fromString(_redact(st.toString()));
    final sink = _sink;
    if (sink != null) {
      sink(LogEntry(
        level: level,
        tag: tag,
        message: safeMessage,
        stackTrace: safeStackTrace,
      ));
      return;
    }
    developer.log(
      safeMessage,
      name: '${level.name.toUpperCase()}/$tag',
      level: _levelValue(level),
      stackTrace: safeStackTrace,
    );
  }

  String _redact(String value) {
    var result = value.replaceAll(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
      '[REDACTED_JWT]',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'''\b(secretKey|privateKey|plaintext|ciphertext|payload|token|authorization)\b\s*[:=]\s*("[^"]*"|'[^']*'|[^\s,;}]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[REDACTED]',
    );
    return result;
  }

  int _levelValue(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      };
}
