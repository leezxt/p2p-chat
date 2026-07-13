ALTER TABLE device_push_tokens RENAME COLUMN token TO token_ciphertext;
ALTER TABLE device_push_tokens ALTER COLUMN token_ciphertext DROP NOT NULL;

-- V6 stored provider tokens as plaintext. Invalidate them instead of treating
-- unknown legacy values as authenticated ciphertext; clients will re-register.
UPDATE device_push_tokens
SET token_ciphertext = NULL,
    revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP),
    updated_at = CURRENT_TIMESTAMP;
