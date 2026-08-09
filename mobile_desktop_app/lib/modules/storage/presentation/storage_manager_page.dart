import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/storage_manager_service.dart';
import '../domain/storage_usage_snapshot.dart';

/// 顯示可回收範圍，使用者確認後才執行快取清理。
class StorageManagerPage extends StatefulWidget {
  const StorageManagerPage({super.key, required this.service});

  final StorageManagerService service;

  @override
  State<StorageManagerPage> createState() => _StorageManagerPageState();
}

class _StorageManagerPageState extends State<StorageManagerPage> {
  StorageUsageSnapshot? _usage;
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final usage = await widget.service.preview();
      if (mounted) setState(() => _usage = usage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndClear() async {
    final usage = _usage;
    if (usage == null || usage.reclaimableBytes == 0 || _clearing) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.storageClearCache),
        content: Text(l10n.storageClearCacheConfirmation(
            formatBytes(usage.reclaimableBytes))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.storageClearCache),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    final cleared = await widget.service.clearRebuildableCache();
    await _reload();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageCacheCleared(formatBytes(cleared)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usage = _usage;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageManager)),
      body: _loading && usage == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.storageTotal(formatBytes(usage?.totalBytes ?? 0)),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _UsageTile(
                    icon: Icons.storage_outlined,
                    title: l10n.storageDatabase,
                    bytes: usage?.databaseBytes ?? 0,
                  ),
                  _UsageTile(
                    icon: Icons.cached_outlined,
                    title: l10n.storageCache,
                    bytes: usage?.cacheBytes ?? 0,
                  ),
                  _UsageTile(
                    icon: Icons.attachment_outlined,
                    title: l10n.storageAttachments,
                    bytes: usage?.attachmentBytes ?? 0,
                  ),
                  const Divider(height: 32),
                  Text(l10n.storageProtected,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(l10n.storageProtectedDescription(
                    formatBytes(usage?.protectedPendingMailboxBytes ?? 0),
                  )),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: usage == null ||
                            usage.reclaimableBytes == 0 ||
                            _clearing
                        ? null
                        : _confirmAndClear,
                    icon: _clearing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cleaning_services_outlined),
                    label: Text(l10n.storageClearCache),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.storageClearCacheDescription,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.icon,
    required this.title,
    required this.bytes,
  });

  final IconData icon;
  final String title;
  final int bytes;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(formatBytes(bytes)),
      );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
