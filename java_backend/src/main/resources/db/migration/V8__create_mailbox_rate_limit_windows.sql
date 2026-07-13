CREATE TABLE mailbox_rate_limit_windows (
    device_id UUID NOT NULL,
    operation VARCHAR(16) NOT NULL,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (device_id, operation, window_start),
    CONSTRAINT ck_mailbox_rate_limit_operation CHECK (operation IN ('UPLOAD', 'READ_ACK')),
    CONSTRAINT ck_mailbox_rate_limit_count CHECK (request_count > 0)
);

CREATE INDEX idx_mailbox_rate_limit_cleanup
    ON mailbox_rate_limit_windows (window_start);
