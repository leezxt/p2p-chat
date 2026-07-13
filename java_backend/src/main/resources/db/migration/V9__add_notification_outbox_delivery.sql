ALTER TABLE notification_outbox DROP CONSTRAINT ck_outbox_state;

ALTER TABLE notification_outbox ADD COLUMN next_attempt_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE notification_outbox ADD COLUMN lease_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE notification_outbox ADD COLUMN lease_token UUID;
ALTER TABLE notification_outbox ADD COLUMN last_error_code VARCHAR(64);

UPDATE notification_outbox
SET next_attempt_at = updated_at
WHERE next_attempt_at IS NULL;

ALTER TABLE notification_outbox ALTER COLUMN next_attempt_at SET NOT NULL;

ALTER TABLE notification_outbox ADD CONSTRAINT ck_outbox_state
    CHECK (state IN ('PENDING', 'PROCESSING', 'SENT', 'FAILED'));

DROP INDEX idx_notification_outbox_pending;
CREATE INDEX idx_notification_outbox_dispatch
    ON notification_outbox (state, next_attempt_at, lease_until, created_at);
