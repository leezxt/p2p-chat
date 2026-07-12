import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logging/logging_service.dart';
import 'migrations.dart';

/// 本機 SQLite 服務：集中管理連線與 migration（規格 §20）。
///
/// 全 App 共用一個 DB，表格按模組命名。開啟時執行 [kMigrations]，
/// 升級時依版本差補齊，確保可追蹤、可回退（規格 §26 規則 14）。
class DatabaseService {
  DatabaseService({
    required this.databaseFactory,
    required LoggingService logger,
    this.fileName = 'p2p_chat.db',
  }) : _logger = logger;

  /// 由呼叫端注入（手機用 sqflite 預設；桌面 / 測試用 ffi）。
  final DatabaseFactory databaseFactory;
  final String fileName;
  final LoggingService _logger;

  Database? _db;
  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService 尚未 open()');
    }
    return database;
  }

  Future<void> open({String? directoryPath}) async {
    if (_db != null) return;
    final basePath = directoryPath ?? await databaseFactory.getDatabasesPath();
    final path = p.join(basePath, fileName);

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kCurrentDbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    _logger.info('db', '已開啟資料庫 v$kCurrentDbVersion @ $path');
  }

  /// 首次建立：套用全部 migration。
  Future<void> _onCreate(Database db, int version) async {
    await _applyMigrations(db, fromExclusive: 0, toInclusive: version);
  }

  /// 升級：只套用尚未執行的 migration。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.info('db', 'migration $oldVersion → $newVersion');
    await _applyMigrations(db,
        fromExclusive: oldVersion, toInclusive: newVersion);
  }

  Future<void> _applyMigrations(
    Database db, {
    required int fromExclusive,
    required int toInclusive,
  }) async {
    for (final migration in kMigrations) {
      if (migration.version <= fromExclusive) continue;
      if (migration.version > toInclusive) break;
      await db.transaction((txn) async {
        for (final sql in migration.statements) {
          await txn.execute(sql);
        }
      });
      _logger.info('db', '套用 migration v${migration.version}');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
