package com.p2pchat.modules.mailbox.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import com.p2pchat.modules.mailbox.data.MailboxRateLimitStore;

@ActiveProfiles("test")
@SpringBootTest
class MailboxRateLimiterTest {
    @Autowired MailboxRateLimitStore store;
    @Autowired JdbcTemplate jdbc;

    @Test
    void uploadAllowsSixtyRequestsAndRejectsTheNextRequestWithRetryAfter() {
        var clock = new MutableClock(Instant.parse("2026-07-13T12:34:45Z"));
        var limiter = new MailboxRateLimiter(store, clock);
        var deviceId = UUID.randomUUID();

        assertThatCode(() -> repeat(60, () -> limiter.checkUpload(deviceId)))
                .doesNotThrowAnyException();

        assertRateLimited(() -> limiter.checkUpload(deviceId), "15");
    }

    @Test
    void readAndAckShareAOneHundredTwentyRequestBudget() {
        var limiter = limiterAt("2026-07-13T12:35:00Z");
        var deviceId = UUID.randomUUID();

        assertThatCode(() -> repeat(120, () -> limiter.checkReadOrAck(deviceId)))
                .doesNotThrowAnyException();

        assertRateLimited(() -> limiter.checkReadOrAck(deviceId), "60");
    }

    @Test
    void limitsAreIsolatedByOperationAndDevice() {
        var limiter = limiterAt("2026-07-13T12:36:00Z");
        var firstDevice = UUID.randomUUID();
        var secondDevice = UUID.randomUUID();

        repeat(60, () -> limiter.checkUpload(firstDevice));

        assertThatCode(() -> limiter.checkUpload(secondDevice)).doesNotThrowAnyException();
        assertThatCode(() -> limiter.checkReadOrAck(firstDevice)).doesNotThrowAnyException();
        assertRateLimited(() -> limiter.checkUpload(firstDevice), "60");
    }

    @Test
    void separateLimiterInstancesShareTheDatabaseBudget() {
        var clock = new MutableClock(Instant.parse("2026-07-13T12:37:00Z"));
        var first = new MailboxRateLimiter(store, clock);
        var second = new MailboxRateLimiter(store, clock);
        var deviceId = UUID.randomUUID();

        repeat(30, () -> first.checkUpload(deviceId));
        repeat(30, () -> second.checkUpload(deviceId));

        assertRateLimited(() -> first.checkUpload(deviceId), "60");
    }

    @Test
    void concurrentRequestsCannotExceedTheSharedLimit() throws Exception {
        var limiter = limiterAt("2026-07-13T12:38:00Z");
        var deviceId = UUID.randomUUID();
        var accepted = new AtomicInteger();
        var rejected = new AtomicInteger();

        try (var executor = Executors.newFixedThreadPool(16)) {
            var tasks = java.util.stream.IntStream.range(0, 80)
                    .mapToObj(ignored -> (java.util.concurrent.Callable<Void>) () -> {
                        try {
                            limiter.checkUpload(deviceId);
                            accepted.incrementAndGet();
                        } catch (ResponseStatusException exception) {
                            assertThat(exception.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                            rejected.incrementAndGet();
                        }
                        return null;
                    }).toList();
            for (var future : executor.invokeAll(tasks)) future.get();
        }

        assertThat(accepted).hasValue(MailboxRateLimiter.UPLOAD_LIMIT);
        assertThat(rejected).hasValue(20);
    }

    @Test
    void advancingToTheNextMinuteStartsANewWindow() {
        var clock = new MutableClock(Instant.parse("2026-07-13T12:39:59Z"));
        var limiter = new MailboxRateLimiter(store, clock);
        var deviceId = UUID.randomUUID();

        repeat(60, () -> limiter.checkUpload(deviceId));
        assertRateLimited(() -> limiter.checkUpload(deviceId), "1");

        clock.advance(Duration.ofSeconds(1));
        assertThatCode(() -> limiter.checkUpload(deviceId)).doesNotThrowAnyException();
    }

    @Test
    void cleanupKeepsCurrentAndPreviousWindows() {
        var clock = new MutableClock(Instant.parse("2026-07-13T12:42:00Z"));
        var limiter = new MailboxRateLimiter(store, clock);
        var oldDevice = UUID.randomUUID();
        var previousDevice = UUID.randomUUID();
        var currentDevice = UUID.randomUUID();

        new MailboxRateLimiter(store, new MutableClock(Instant.parse("2026-07-13T12:40:00Z")))
                .checkUpload(oldDevice);
        new MailboxRateLimiter(store, new MutableClock(Instant.parse("2026-07-13T12:41:00Z")))
                .checkUpload(previousDevice);
        limiter.checkUpload(currentDevice);

        limiter.cleanupExpiredWindows();

        assertThat(windowCount(oldDevice)).isZero();
        assertThat(windowCount(previousDevice)).isOne();
        assertThat(windowCount(currentDevice)).isOne();
    }

    @Test
    void mvcResponseIncludesRetryAfterHeader() throws Exception {
        var mvc = MockMvcBuilders.standaloneSetup(new RateLimitedController()).build();

        mvc.perform(get("/rate-limited"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string(HttpHeaders.RETRY_AFTER, "23"));
    }

    private MailboxRateLimiter limiterAt(String instant) {
        return new MailboxRateLimiter(store, new MutableClock(Instant.parse(instant)));
    }

    private int windowCount(UUID deviceId) {
        return jdbc.queryForObject(
                "SELECT COUNT(*) FROM mailbox_rate_limit_windows WHERE device_id = ?",
                Integer.class, deviceId);
    }

    private static void assertRateLimited(Runnable request, String retryAfter) {
        assertThatThrownBy(request::run)
                .isInstanceOfSatisfying(ResponseStatusException.class, exception -> {
                    assertThat(exception.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(exception.getReason()).isEqualTo("MAILBOX_RATE_LIMITED");
                    assertThat(exception.getHeaders().getFirst(HttpHeaders.RETRY_AFTER)).isEqualTo(retryAfter);
                });
    }

    private static void repeat(int count, Runnable request) {
        for (int index = 0; index < count; index++) request.run();
    }

    private static final class MutableClock extends Clock {
        private Instant instant;

        private MutableClock(Instant instant) {
            this.instant = instant;
        }

        void advance(Duration duration) {
            instant = instant.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return instant;
        }
    }

    @RestController
    private static final class RateLimitedController {
        @GetMapping("/rate-limited")
        void rateLimited() {
            throw new MailboxRateLimitException(23);
        }
    }
}
