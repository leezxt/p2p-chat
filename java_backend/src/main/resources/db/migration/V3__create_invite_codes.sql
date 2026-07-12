CREATE TABLE invite_codes (
    id UUID PRIMARY KEY,
    inviter_user_id UUID NOT NULL,
    code_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    redeemed_by_user_id UUID,
    redeemed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_invite_codes_inviter FOREIGN KEY (inviter_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_invite_codes_redeemer FOREIGN KEY (redeemed_by_user_id) REFERENCES users (id),
    CONSTRAINT uq_invite_codes_hash UNIQUE (code_hash),
    CONSTRAINT ck_invite_codes_redemption_pair CHECK (
        (redeemed_by_user_id IS NULL AND redeemed_at IS NULL)
        OR (redeemed_by_user_id IS NOT NULL AND redeemed_at IS NOT NULL)
    )
);

CREATE INDEX idx_invite_codes_expiry ON invite_codes (expires_at);
