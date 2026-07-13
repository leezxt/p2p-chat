package com.p2pchat.modules.mailbox.domain;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import com.p2pchat.modules.mailbox.data.MailboxRateLimitStore;

@Component
public class MailboxRateLimiter {
    static final int UPLOAD_LIMIT = 60;
    static final int READ_ACK_LIMIT = 120;
    private final MailboxRateLimitStore store;
    private final Clock clock;

    @Autowired
    public MailboxRateLimiter(MailboxRateLimitStore store) {
        this(store, Clock.systemUTC());
    }

    MailboxRateLimiter(MailboxRateLimitStore store, Clock clock) {
        this.store = store;
        this.clock = clock;
    }

    public void checkUpload(UUID deviceId) {
        check(deviceId, "UPLOAD", UPLOAD_LIMIT);
    }

    public void checkReadOrAck(UUID deviceId) {
        check(deviceId, "READ_ACK", READ_ACK_LIMIT);
    }

    private void check(UUID deviceId, String operation, int limit) {
        Instant now = clock.instant();
        Instant windowStart = Instant.ofEpochSecond(Math.floorDiv(now.getEpochSecond(), 60) * 60);
        if (store.increment(deviceId, operation, windowStart, now) <= limit) return;

        long retryAfterSeconds = 60 - Math.floorMod(now.getEpochSecond(), 60);
        throw new MailboxRateLimitException(retryAfterSeconds);
    }

    @Scheduled(fixedDelayString = "${app.mailbox.rate-limit-cleanup-delay:PT5M}")
    public void cleanupExpiredWindows() {
        Instant currentWindow = Instant.ofEpochSecond(Math.floorDiv(clock.instant().getEpochSecond(), 60) * 60);
        store.deleteBefore(currentWindow.minusSeconds(60));
    }
}
