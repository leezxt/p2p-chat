enum MailboxDeliveryState {
  stored,
  delivered,
  read,
  expired;

  String get wire => name.toUpperCase();

  static MailboxDeliveryState fromWire(String value) {
    for (final state in values) {
      if (state.wire == value.toUpperCase()) return state;
    }
    throw const FormatException('Unknown mailbox delivery state');
  }

  bool canAdvanceTo(MailboxDeliveryState next) => switch (this) {
        stored => next == stored || next == delivered || next == expired,
        delivered => next == delivered || next == read,
        read => next == read,
        expired => next == expired,
      };

  MailboxDeliveryState advanceTo(MailboxDeliveryState next) {
    if (!canAdvanceTo(next)) {
      throw MailboxStateTransitionException(this, next);
    }
    return next;
  }
}

class MailboxStateTransitionException implements Exception {
  const MailboxStateTransitionException(this.current, this.requested);

  final MailboxDeliveryState current;
  final MailboxDeliveryState requested;

  @override
  String toString() =>
      'MailboxStateTransitionException(${current.wire}->${requested.wire})';
}

class MailboxAck {
  const MailboxAck({
    required this.mailboxMessageId,
    required this.messageId,
    required this.acknowledgingDeviceId,
    required this.status,
    required this.occurredAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String mailboxMessageId;
  final String messageId;
  final String acknowledgingDeviceId;
  final MailboxDeliveryState status;
  final int occurredAt;

  String get idempotencyKey =>
      '$mailboxMessageId:$acknowledgingDeviceId:${status.wire}';

  Map<String, Object?> toWireJson() {
    if (status != MailboxDeliveryState.delivered &&
        status != MailboxDeliveryState.read) {
      throw const FormatException('ACK status must be DELIVERED or READ');
    }
    _validateIdentifier(mailboxMessageId);
    _validateIdentifier(messageId);
    _validateIdentifier(acknowledgingDeviceId);
    if (occurredAt <= 0) throw const FormatException('Invalid ACK time');
    return {
      'schemaVersion': schemaVersion,
      'mailboxMessageId': mailboxMessageId,
      'messageId': messageId,
      'acknowledgingDeviceId': acknowledgingDeviceId,
      'status': status.wire,
      'occurredAt': occurredAt,
    };
  }

  factory MailboxAck.fromWireJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw const FormatException('Unsupported ACK schema version');
    }
    final ack = MailboxAck(
      schemaVersion: version as int,
      mailboxMessageId: _requiredString(json, 'mailboxMessageId'),
      messageId: _requiredString(json, 'messageId'),
      acknowledgingDeviceId: _requiredString(
        json,
        'acknowledgingDeviceId',
      ),
      status: MailboxDeliveryState.fromWire(
        _requiredString(json, 'status'),
      ),
      occurredAt: json['occurredAt'] as int,
    );
    ack.toWireJson();
    return ack;
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw const FormatException('Invalid ACK');
    _validateIdentifier(value);
    return value;
  }

  static void _validateIdentifier(String value) {
    if (value.isEmpty || value.length > 256) {
      throw const FormatException('Invalid ACK identifier');
    }
  }
}
