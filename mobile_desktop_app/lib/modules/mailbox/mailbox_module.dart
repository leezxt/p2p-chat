import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/network/backend_api.dart';
import '../chat/data/chat_repository.dart';
import '../crypto/domain/encrypted_message_service.dart';
import '../p2p/domain/p2p_session_manager.dart';
import 'data/http_mailbox_uploader.dart';
import 'data/sqlite_pending_mailbox_queue.dart';
import 'data/sqlite_mailbox_receipts.dart';
import 'domain/mailbox_client.dart';
import 'domain/mailbox_sync_service.dart';
import 'domain/mailbox_uploader.dart';
import 'domain/message_transport_coordinator.dart';
import '../identity/domain/identity_session.dart';
import '../contacts/domain/contact_service.dart';
import 'domain/mailbox_refresh_service.dart';

class MailboxModule extends AppModule {
  MailboxSyncService? _sync;
  @override
  String get name => 'mailbox';

  @override
  Future<void> init(ModuleContext context) async {
    if (!context.services.isRegistered<AccessSession>() ||
        !context.services.isRegistered<MessageCipher>() ||
        !context.services.isRegistered<P2pSessionManager>() ||
        !context.services.isRegistered<ChatRepository>()) {
      context.logger.debug('mailbox', '必要服務尚未就緒，保持 sleeping');
      return;
    }
    final baseUrl = context.config.getString('backendUrl', fallback: '');
    if (baseUrl.isEmpty) return;
    final queue = SqlitePendingMailboxQueue(
      context.services.get<DatabaseService>().db,
    );
    final receipts = SqliteMailboxReceipts(
      context.services.get<DatabaseService>().db,
    );
    final uploader = HttpMailboxUploader(
      baseUrl: baseUrl,
      accessToken: context.services.get<AccessSession>().token,
    );
    final repository = context.services.get<ChatRepository>();
    final coordinator = MessageTransportCoordinator(
      cipher: context.services.get<MessageCipher>(),
      peer: context.services.get<P2pSessionManager>(),
      pendingQueue: queue,
      mailbox: uploader,
      updateStatus: repository.updateStatus,
    );
    context.services.registerSingleton<SqlitePendingMailboxQueue>(queue);
    context.services.registerSingleton<MailboxUploader>(uploader);
    context.services.registerSingleton<MailboxClient>(uploader);
    context.services.registerSingleton<MessageTransportCoordinator>(
      coordinator,
    );
    _sync = MailboxSyncService(
      client: uploader,
      cipher: context.services.get<MessageCipher>(),
      receipts: receipts,
      localDeviceId: context.services.get<IdentitySession>().deviceId,
      saveIncoming: repository.saveIncomingMessage,
      updateStatus: repository.updateStatus,
    );
    context.services.registerSingleton<SqliteMailboxReceipts>(receipts);
    context.services.registerSingleton<MailboxSyncService>(_sync!);
    context.services.registerSingleton<MailboxRefreshService>(
      MailboxRefreshService(
        mailbox: _sync!,
        contacts: context.services.isRegistered<ContactService>()
            ? context.services.get<ContactService>()
            : null,
      ),
    );
  }

  @override
  Future<void> activate() async {
    await _sync?.syncIncoming();
    await _sync?.syncSenderStatuses();
  }

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
