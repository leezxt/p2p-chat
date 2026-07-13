package com.p2pchat.modules.mailbox.data;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class MailboxRateLimitStore {
    private final JdbcTemplate jdbc;

    public MailboxRateLimitStore(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int increment(UUID deviceId, String operation, Instant windowStart, Instant now) {
        int inserted = jdbc.update("""
                INSERT INTO mailbox_rate_limit_windows
                    (device_id, operation, window_start, request_count, updated_at)
                VALUES (?, ?, ?, 1, ?)
                ON CONFLICT DO NOTHING
                """, deviceId, operation, Timestamp.from(windowStart), Timestamp.from(now));
        if (inserted == 1) return 1;

        jdbc.update("""
                UPDATE mailbox_rate_limit_windows
                SET request_count = request_count + 1, updated_at = ?
                WHERE device_id = ? AND operation = ? AND window_start = ?
                """, Timestamp.from(now), deviceId, operation, Timestamp.from(windowStart));
        return jdbc.queryForObject("""
                SELECT request_count
                FROM mailbox_rate_limit_windows
                WHERE device_id = ? AND operation = ? AND window_start = ?
                """, Integer.class, deviceId, operation, Timestamp.from(windowStart));
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int deleteBefore(Instant cutoff) {
        return jdbc.update("DELETE FROM mailbox_rate_limit_windows WHERE window_start < ?",
                Timestamp.from(cutoff));
    }
}
