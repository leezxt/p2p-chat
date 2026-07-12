CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(50),
    display_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_users_username UNIQUE (username)
);

CREATE TABLE devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    public_key_fingerprint VARCHAR(128) NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_devices_public_key_fingerprint UNIQUE (public_key_fingerprint)
);

CREATE INDEX idx_devices_user_id ON devices (user_id);

CREATE TABLE contacts (
    id UUID PRIMARY KEY,
    owner_user_id UUID NOT NULL,
    contact_user_id UUID NOT NULL,
    alias VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_contacts_owner FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_contacts_contact FOREIGN KEY (contact_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_contacts_owner_contact UNIQUE (owner_user_id, contact_user_id),
    CONSTRAINT ck_contacts_not_self CHECK (owner_user_id <> contact_user_id)
);

CREATE INDEX idx_contacts_contact_user_id ON contacts (contact_user_id);
