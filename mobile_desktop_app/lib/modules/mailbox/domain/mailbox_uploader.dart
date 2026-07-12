import '../../crypto/domain/encrypted_envelope.dart';

abstract class MailboxUploader {
  Future<void> upload(EncryptedEnvelope envelope);
}
