import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_ack.dart';

void main() {
  test('ACK wire schema round-trip 且 idempotency key 穩定', () {
    const ack = MailboxAck(
      mailboxMessageId: 'mailbox-1',
      messageId: 'message-1',
      acknowledgingDeviceId: 'device-b',
      status: MailboxDeliveryState.delivered,
      occurredAt: 100,
    );

    final decoded = MailboxAck.fromWireJson(ack.toWireJson());

    expect(decoded.status, MailboxDeliveryState.delivered);
    expect(decoded.idempotencyKey, 'mailbox-1:device-b:DELIVERED');
  });

  test('允許 STORED 到 DELIVERED/EXPIRED 與 DELIVERED 到 READ', () {
    expect(
      MailboxDeliveryState.stored.advanceTo(
        MailboxDeliveryState.delivered,
      ),
      MailboxDeliveryState.delivered,
    );
    expect(
      MailboxDeliveryState.delivered.advanceTo(MailboxDeliveryState.read),
      MailboxDeliveryState.read,
    );
    expect(
      MailboxDeliveryState.stored.advanceTo(MailboxDeliveryState.expired),
      MailboxDeliveryState.expired,
    );
  });

  test('相同狀態 ACK 冪等，倒退與 terminal state 轉換被拒絕', () {
    expect(
      MailboxDeliveryState.read.advanceTo(MailboxDeliveryState.read),
      MailboxDeliveryState.read,
    );
    for (final transition in [
      (MailboxDeliveryState.read, MailboxDeliveryState.delivered),
      (MailboxDeliveryState.delivered, MailboxDeliveryState.stored),
      (MailboxDeliveryState.expired, MailboxDeliveryState.delivered),
    ]) {
      expect(
        () => transition.$1.advanceTo(transition.$2),
        throwsA(isA<MailboxStateTransitionException>()),
      );
    }
  });

  test('拒絕未知狀態、STORED ACK、錯版本與空 identifier', () {
    expect(
      () => MailboxDeliveryState.fromWire('UNKNOWN'),
      throwsFormatException,
    );
    expect(
      () => const MailboxAck(
        mailboxMessageId: 'mailbox-1',
        messageId: 'message-1',
        acknowledgingDeviceId: 'device-b',
        status: MailboxDeliveryState.stored,
        occurredAt: 100,
      ).toWireJson(),
      throwsFormatException,
    );
    expect(
      () => MailboxAck.fromWireJson({
        'schemaVersion': 2,
        'mailboxMessageId': 'mailbox-1',
        'messageId': 'message-1',
        'acknowledgingDeviceId': 'device-b',
        'status': 'DELIVERED',
        'occurredAt': 100,
      }),
      throwsFormatException,
    );
  });
}
