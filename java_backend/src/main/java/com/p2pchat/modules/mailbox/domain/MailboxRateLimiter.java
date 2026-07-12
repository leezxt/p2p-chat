package com.p2pchat.modules.mailbox.domain;

import java.time.Clock;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class MailboxRateLimiter {
    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final Clock clock = Clock.systemUTC();

    public void checkUpload(UUID deviceId) { check("upload:" + deviceId, 60); }
    public void checkReadOrAck(UUID deviceId) { check("read:" + deviceId, 120); }

    private void check(String key, int limit) {
        long minute = clock.instant().getEpochSecond() / 60;
        Window result = windows.compute(key, (ignored, current) -> {
            if (current == null || current.minute != minute) return new Window(minute, 1);
            return new Window(minute, current.count + 1);
        });
        if (result.count > limit)
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "MAILBOX_RATE_LIMITED");
        if (windows.size() > 10_000) windows.entrySet().removeIf(entry -> entry.getValue().minute < minute - 1);
    }

    private record Window(long minute, int count) {}
}
