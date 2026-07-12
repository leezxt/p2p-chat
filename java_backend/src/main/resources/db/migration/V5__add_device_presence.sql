ALTER TABLE devices ADD COLUMN last_seen_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX idx_devices_last_seen ON devices (last_seen_at);
