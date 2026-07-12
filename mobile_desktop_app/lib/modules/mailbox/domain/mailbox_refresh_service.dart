import '../../contacts/domain/contact_service.dart';
import 'mailbox_sync_service.dart';

/// Refreshes all data required after a manual sync or notification launch.
class MailboxRefreshService {
  MailboxRefreshService({
    required MailboxSyncService mailbox,
    ContactService? contacts,
  })  : _mailbox = mailbox,
        _contacts = contacts;

  final MailboxSyncService _mailbox;
  final ContactService? _contacts;

  Future<void> refresh() async {
    await _contacts?.syncContacts();
    await _mailbox.syncIncoming();
    await _mailbox.syncSenderStatuses();
  }
}
