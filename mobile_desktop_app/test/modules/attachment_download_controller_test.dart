import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/modules/attachment/domain/attachment_download_controller.dart';
import 'package:p2p_chat_app/modules/attachment/domain/attachment_metadata.dart';
import 'package:p2p_chat_app/modules/attachment/domain/attachment_transfer.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

void main() {
  test('attachment metadata 拒絕錯誤格式、種類與超過上限', () {
    expect(
      () => AttachmentMetadata(
        attachmentId: 'a',
        kind: AttachmentKind.image,
        mimeType: 'image/gif',
        byteSize: 1,
        ciphertextSha256: '0' * 64,
      ),
      throwsFormatException,
    );
    expect(
      () => AttachmentMetadata(
        attachmentId: 'a',
        kind: AttachmentKind.voice,
        mimeType: 'audio/ogg',
        byteSize: AttachmentMetadata.voiceMaxBytes + 1,
        ciphertextSha256: '0' * 64,
      ),
      throwsFormatException,
    );
  });

  test('image 自動下載只在一般模式且使用者允許時執行', () async {
    final transfer = _FakeTransfer();
    final config = ConfigService(initial: {'autoDownloadImages': true});
    final controller = AttachmentDownloadController(
      transfer: transfer,
      resourcePolicy: ResourcePolicyService(config),
    );
    final image = _image();

    await controller.request(image, manual: false);
    expect(controller.stateFor(image.attachmentId),
        AttachmentDownloadState.available);
    expect(transfer.downloads, 1);

    config.lowPowerMode = true;
    final blocked = _image(id: 'b');
    await controller.request(blocked, manual: false);
    expect(controller.stateFor(blocked.attachmentId),
        AttachmentDownloadState.blockedByPolicy);
    expect(transfer.downloads, 1);
  });

  test('voice 永遠不自動下載，失敗後可手動重試並取消', () async {
    final transfer = _FakeTransfer(failures: 1);
    final controller = AttachmentDownloadController(
      transfer: transfer,
      resourcePolicy: ResourcePolicyService(
        ConfigService(initial: {'autoDownloadImages': true}),
      ),
    );
    final voice = AttachmentMetadata(
      attachmentId: 'voice',
      kind: AttachmentKind.voice,
      mimeType: 'audio/ogg',
      byteSize: 512,
      ciphertextSha256: '1' * 64,
    );

    await controller.request(voice, manual: false);
    expect(
        controller.stateFor('voice'), AttachmentDownloadState.blockedByPolicy);

    await controller.request(voice, manual: true);
    expect(controller.stateFor('voice'), AttachmentDownloadState.failed);
    await controller.request(voice, manual: true);
    expect(controller.stateFor('voice'), AttachmentDownloadState.available);

    final pending = _image(id: 'pending');
    final delayed = _FakeTransfer(delayed: true);
    final pendingController = AttachmentDownloadController(
      transfer: delayed,
      resourcePolicy: ResourcePolicyService(ConfigService()),
    );
    final request = pendingController.request(pending, manual: true);
    await Future<void>.delayed(Duration.zero);
    await pendingController.cancel(pending.attachmentId);
    delayed.complete();
    await request;
    expect(delayed.cancelled, ['pending']);
    expect(pendingController.stateFor('pending'),
        AttachmentDownloadState.cancelled);
  });

  test('attachment payload 只接受版本化 metadata', () {
    final envelope = MessageEnvelope(
      messageId: 'm',
      conversationId: 'c',
      senderUserId: 'u',
      senderDeviceId: 'd',
      type: MessageType.image,
      payload: _image().toPayload(),
      createdAt: 1,
    );
    expect(
        AttachmentMetadata.fromEnvelope(envelope).kind, AttachmentKind.image);
  });
}

AttachmentMetadata _image({String id = 'image'}) => AttachmentMetadata(
      attachmentId: id,
      kind: AttachmentKind.image,
      mimeType: 'image/png',
      byteSize: 1024,
      ciphertextSha256: 'a' * 64,
    );

class _FakeTransfer implements AttachmentTransfer {
  _FakeTransfer({this.failures = 0, this.delayed = false});

  int failures;
  final bool delayed;
  int downloads = 0;
  final cancelled = <String>[];
  final _completer = Completer<void>();

  @override
  Future<void> cancel(String attachmentId) async {
    cancelled.add(attachmentId);
  }

  @override
  Future<void> download(AttachmentMetadata attachment) async {
    downloads++;
    if (failures > 0) {
      failures--;
      throw StateError('network');
    }
    if (delayed) await _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
