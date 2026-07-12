CREATE TABLE mailbox_messages (
    id UUID PRIMARY KEY,
    message_id VARCHAR(256) NOT NULL,
    sender_device_id UUID NOT NULL,
    recipient_device_id UUID NOT NULL,
    sender_key_id VARCHAR(256) NOT NULL,
    recipient_key_id VARCHAR(256) NOT NULL,
    nonce VARCHAR(64) NOT NULL,
    ciphertext TEXT,
    ciphertext_bytes INTEGER NOT NULL,
    state VARCHAR(16) NOT NULL,
    stored_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_mailbox_sender_device FOREIGN KEY (sender_device_id) REFERENCES devices (id),
    CONSTRAINT fk_mailbox_recipient_device FOREIGN KEY (recipient_device_id) REFERENCES devices (id),
    CONSTRAINT uq_mailbox_sender_message UNIQUE (sender_device_id, message_id),
    CONSTRAINT ck_mailbox_state CHECK (state IN ('STORED', 'DELIVERED', 'READ', 'EXPIRED')),
    CONSTRAINT ck_mailbox_ciphertext_bytes CHECK (ciphertext_bytes >= 0 AND ciphertext_bytes <= 1048576)
);

CREATE INDEX idx_mailbox_recipient_state_stored
    ON mailbox_messages (recipient_device_id, state, stored_at, id);
CREATE INDEX idx_mailbox_sender_updated
    ON mailbox_messages (sender_device_id, updated_at, id);
CREATE INDEX idx_mailbox_expiry ON mailbox_messages (state, expires_at);
