package com.p2pchat.modules.push.domain;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import com.p2pchat.modules.push.data.NotificationOutboxRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationOutboxDispatchService {
    private final NotificationOutboxRepository outbox;

    public NotificationOutboxDispatchService(NotificationOutboxRepository outbox) {
        this.outbox = outbox;
    }

    @Transactional
    public Optional<Claim> claimNext(Instant now, Duration leaseDuration) {
        var candidates = outbox.findDispatchable(now, PageRequest.of(0, 1));
        if (candidates.isEmpty()) return Optional.empty();
        var item = candidates.getFirst();
        UUID leaseToken = UUID.randomUUID();
        item.claim(leaseToken, now, now.plus(leaseDuration));
        return Optional.of(new Claim(item.getId(), item.getRecipientDevice().getId(), item.getAttempts(),
                leaseToken, item.hasExpectedPayload()));
    }

    @Transactional
    public boolean markSent(Claim claim, Instant now, String resultCode) {
        return outbox.findById(claim.outboxId())
                .map(item -> item.markSent(claim.leaseToken(), now, resultCode)).orElse(false);
    }

    @Transactional
    public boolean retry(Claim claim, Instant now, Instant retryAt, String errorCode) {
        return outbox.findById(claim.outboxId())
                .map(item -> item.retry(claim.leaseToken(), now, retryAt, errorCode)).orElse(false);
    }

    @Transactional
    public boolean fail(Claim claim, Instant now, String errorCode) {
        return outbox.findById(claim.outboxId())
                .map(item -> item.fail(claim.leaseToken(), now, errorCode)).orElse(false);
    }

    public record Claim(UUID outboxId, UUID recipientDeviceId, int attempts,
            UUID leaseToken, boolean expectedPayload) {}
}
