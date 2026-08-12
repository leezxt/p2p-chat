import 'package:crypto/crypto.dart';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_type.dart';

enum AttachmentKind { image, voice }

/// 僅描述加密附件，實際 bytes 永遠不放進訊息 payload 或日誌。
class AttachmentMetadata {
  AttachmentMetadata({
    required this.attachmentId,
    required this.kind,
    required this.mimeType,
    required this.byteSize,
    required this.ciphertextSha256,
  }) {
    if (attachmentId.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(ciphertextSha256) ||
        byteSize <= 0 ||
        byteSize > maxBytesFor(kind) ||
        !_validMime(kind, mimeType)) {
      throw const FormatException('Invalid attachment metadata');
    }
  }

  static const imageMaxBytes = 10 * 1024 * 1024;
  static const voiceMaxBytes = 25 * 1024 * 1024;

  final String attachmentId;
  final AttachmentKind kind;
  final String mimeType;
  final int byteSize;
  final String ciphertextSha256;

  static int maxBytesFor(AttachmentKind kind) => switch (kind) {
        AttachmentKind.image => imageMaxBytes,
        AttachmentKind.voice => voiceMaxBytes,
      };

  static bool _validMime(AttachmentKind kind, String mimeType) =>
      switch (kind) {
        AttachmentKind.image =>
          mimeType == 'image/jpeg' || mimeType == 'image/png',
        AttachmentKind.voice =>
          mimeType == 'audio/ogg' || mimeType == 'audio/m4a',
      };

  Map<String, Object?> toPayload() => {
        'schemaVersion': 1,
        'attachmentId': attachmentId,
        'mimeType': mimeType,
        'byteSize': byteSize,
        'ciphertextSha256': ciphertextSha256,
      };

  factory AttachmentMetadata.fromEnvelope(MessageEnvelope envelope) {
    final kind = switch (envelope.type) {
      MessageType.image => AttachmentKind.image,
      MessageType.voiceMessage => AttachmentKind.voice,
      _ => throw const FormatException('Envelope is not an attachment'),
    };
    final payload = envelope.payload;
    if (payload.length != 5 ||
        payload['schemaVersion'] != 1 ||
        payload['attachmentId'] is! String ||
        payload['mimeType'] is! String ||
        payload['byteSize'] is! int ||
        payload['ciphertextSha256'] is! String) {
      throw const FormatException('Invalid attachment payload');
    }
    return AttachmentMetadata(
      attachmentId: payload['attachmentId']! as String,
      kind: kind,
      mimeType: payload['mimeType']! as String,
      byteSize: payload['byteSize']! as int,
      ciphertextSha256: payload['ciphertextSha256']! as String,
    );
  }

  static String sha256ForCiphertext(List<int> bytes) =>
      sha256.convert(bytes).toString();
}
