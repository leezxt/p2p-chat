CREATE TABLE device_push_tokens (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL,
    provider VARCHAR(16) NOT NULL,
    token TEXT NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_push_token_device FOREIGN KEY (device_id) REFERENCES devices (id) ON DELETE CASCADE,
    CONSTRAINT uq_push_token_device_provider UNIQUE (device_id, provider),
    CONSTRAINT uq_push_token_provider_hash UNIQUE (provider, token_hash),
    CONSTRAINT ck_push_token_provider CHECK (provider IN ('FCM', 'APNS'))
);

CREATE INDEX idx_push_tokens_active ON device_push_tokens (device_id, revoked_at);

CREATE TABLE notification_outbox (
    id UUID PRIMARY KEY,
    mailbox_message_id UUID NOT NULL,
    recipient_device_id UUID NOT NULL,
    event_type VARCHAR(32) NOT NULL,
    payload_json VARCHAR(256) NOT NULL,
    state VARCHAR(16) NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_outbox_mailbox FOREIGN KEY (mailbox_message_id) REFERENCES mailbox_messages (id) ON DELETE CASCADE,
    CONSTRAINT fk_outbox_recipient FOREIGN KEY (recipient_device_id) REFERENCES devices (id) ON DELETE CASCADE,
    CONSTRAINT uq_outbox_mailbox_event UNIQUE (mailbox_message_id, event_type),
    CONSTRAINT ck_outbox_event CHECK (event_type = 'MAILBOX_AVAILABLE'),
    CONSTRAINT ck_outbox_state CHECK (state IN ('PENDING', 'SENT', 'FAILED')),
    CONSTRAINT ck_outbox_attempts CHECK (attempts >= 0)
);

CREATE INDEX idx_notification_outbox_pending ON notification_outbox (state, created_at);
