package com.p2pchat.modules.mailbox.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class MailboxRateLimiterTest {

    @Test
    void uploadAllowsSixtyRequestsAndRejectsTheNextRequest() {
        var limiter = new MailboxRateLimiter();
        var deviceId = UUID.randomUUID();

        assertThatCode(() -> repeat(60, () -> limiter.checkUpload(deviceId)))
                .doesNotThrowAnyException();

        assertRateLimited(() -> limiter.checkUpload(deviceId));
    }

    @Test
    void readAndAckShareAOneHundredTwentyRequestBudget() {
        var limiter = new MailboxRateLimiter();
        var deviceId = UUID.randomUUID();

        assertThatCode(() -> repeat(120, () -> limiter.checkReadOrAck(deviceId)))
                .doesNotThrowAnyException();

        assertRateLimited(() -> limiter.checkReadOrAck(deviceId));
    }

    @Test
    void limitsAreIsolatedByOperationAndDevice() {
        var limiter = new MailboxRateLimiter();
        var firstDevice = UUID.randomUUID();
        var secondDevice = UUID.randomUUID();

        repeat(60, () -> limiter.checkUpload(firstDevice));

        assertThatCode(() -> limiter.checkUpload(secondDevice)).doesNotThrowAnyException();
        assertThatCode(() -> limiter.checkReadOrAck(firstDevice)).doesNotThrowAnyException();
        assertRateLimited(() -> limiter.checkUpload(firstDevice));
    }

    private static void assertRateLimited(Runnable request) {
        assertThatThrownBy(request::run)
                .isInstanceOfSatisfying(ResponseStatusException.class, exception -> {
                    assertThat(exception.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(exception.getReason()).isEqualTo("MAILBOX_RATE_LIMITED");
                });
    }

    private static void repeat(int count, Runnable request) {
        for (int index = 0; index < count; index++) request.run();
    }
}
