package com.p2pchat.modules.mailbox.domain;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

final class MailboxRateLimitException extends ResponseStatusException {
    private final HttpHeaders headers = new HttpHeaders();

    MailboxRateLimitException(long retryAfterSeconds) {
        super(HttpStatus.TOO_MANY_REQUESTS, "MAILBOX_RATE_LIMITED");
        headers.set(HttpHeaders.RETRY_AFTER, Long.toString(retryAfterSeconds));
    }

    @Override
    public HttpHeaders getHeaders() {
        return headers;
    }
}
