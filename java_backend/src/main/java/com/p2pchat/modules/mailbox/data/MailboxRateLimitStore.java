package com.p2pchat.modules.mailbox.data;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class MailboxRateLimitStore {
    private final JdbcTemplate jdbc;
    private final boolean supportsOnConflict;

    public MailboxRateLimitStore(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        String product = jdbc.execute((ConnectionCallback<String>) connection ->
                connection.getMetaData().getDatabaseProductName());
        this.supportsOnConflict = "PostgreSQL".equalsIgnoreCase(product);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int increment(UUID deviceId, String operation, Instant windowStart, Instant now) {
        int inserted = insertWindow(deviceId, operation, windowStart, now);
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

    private int insertWindow(UUID deviceId, String operation, Instant windowStart, Instant now) {
        if (supportsOnConflict) {
            return jdbc.update("""
                    INSERT INTO mailbox_rate_limit_windows
                        (device_id, operation, window_start, request_count, updated_at)
                    VALUES (?, ?, ?, 1, ?)
                    ON CONFLICT DO NOTHING
                    """, deviceId, operation, Timestamp.from(windowStart), Timestamp.from(now));
        }
        try {
            return jdbc.update("""
                    INSERT INTO mailbox_rate_limit_windows
                        (device_id, operation, window_start, request_count, updated_at)
                    VALUES (?, ?, ?, 1, ?)
                    """, deviceId, operation, Timestamp.from(windowStart), Timestamp.from(now));
        } catch (DuplicateKeyException ignored) {
            return 0;
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int deleteBefore(Instant cutoff) {
        return jdbc.update("DELETE FROM mailbox_rate_limit_windows WHERE window_start < ?",
                Timestamp.from(cutoff));
    }
}
