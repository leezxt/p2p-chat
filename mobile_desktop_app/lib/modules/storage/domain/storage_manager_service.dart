import '../data/sqlite_storage_repository.dart';
import 'storage_usage_snapshot.dart';

/// 提供預覽優先的本機空間管理；刪除前由 UI 顯示唯一可清理的範圍。
class StorageManagerService {
  StorageManagerService(this._repository);

  final SqliteStorageRepository _repository;

  Future<StorageUsageSnapshot> preview() => _repository.usage();

  Future<int> clearRebuildableCache() => _repository.clearCache();
}
