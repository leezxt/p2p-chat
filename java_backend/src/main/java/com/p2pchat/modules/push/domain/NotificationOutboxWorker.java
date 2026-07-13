package com.p2pchat.modules.push.domain;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.push.delivery.enabled", havingValue = "true")
public class NotificationOutboxWorker {
    static final int MAX_ATTEMPTS = 8;
    private static final Duration LEASE_DURATION = Duration.ofMinutes(2);
    private static final Duration MAX_RETRY_DELAY = Duration.ofMinutes(15);
    private final NotificationOutboxDispatchService dispatch;
    private final PushTokenDeliveryService tokens;
    private final Map<PushProvider, PushGateway> gateways;
    private final Clock clock;
    private final int batchSize;

    @Autowired
    public NotificationOutboxWorker(NotificationOutboxDispatchService dispatch,
            PushTokenDeliveryService tokens, List<PushGateway> gateways,
            @Value("${app.push.delivery.batch-size:50}") int batchSize) {
        this(dispatch, tokens, gateways, Clock.systemUTC(), batchSize);
    }

    NotificationOutboxWorker(NotificationOutboxDispatchService dispatch,
            PushTokenDeliveryService tokens, List<PushGateway> gateways, Clock clock, int batchSize) {
        if (gateways.isEmpty()) throw new IllegalStateException("Push delivery requires a provider gateway");
        this.dispatch = dispatch;
        this.tokens = tokens;
        this.clock = clock;
        this.batchSize = Math.min(Math.max(batchSize, 1), 500);
        this.gateways = new EnumMap<>(PushProvider.class);
        gateways.forEach(gateway -> {
            if (this.gateways.put(gateway.provider(), gateway) != null)
                throw new IllegalStateException("Duplicate push provider gateway");
        });
    }

    @Scheduled(fixedDelayString = "${app.push.delivery.poll-delay:PT5S}")
    public void dispatchPending() {
        for (int index = 0; index < batchSize && dispatchOne(); index++) {
            // Continue until the batch is full or no due work remains.
        }
    }

    boolean dispatchOne() {
        Instant now = clock.instant();
        var claim = dispatch.claimNext(now, LEASE_DURATION);
        if (claim.isEmpty()) return false;
        var item = claim.orElseThrow();
        if (!item.expectedPayload()) {
            dispatch.fail(item, now, "PUSH_PAYLOAD_INVALID");
            return true;
        }

        var activeTokens = tokens.activeTokens(item.recipientDeviceId());
        if (activeTokens.isEmpty()) {
            dispatch.markSent(item, now, "PUSH_NO_ACTIVE_TOKEN");
            return true;
        }

        boolean delivered = false;
        boolean retryable = false;
        boolean invalidOnly = true;
        String failureCode = "PUSH_PROVIDER_UNAVAILABLE";
        PushNotification notification = PushNotification.mailboxAvailable();
        for (var token : activeTokens) {
            PushGateway gateway = gateways.get(token.provider());
            if (gateway == null) {
                invalidOnly = false;
                continue;
            }
            PushDeliveryResult result;
            try {
                result = gateway.send(token.token(), notification);
            } catch (RuntimeException exception) {
                result = PushDeliveryResult.retryable("PUSH_GATEWAY_EXCEPTION");
            }
            if (result.errorCode() != null) failureCode = result.errorCode();
            switch (result.status()) {
                case DELIVERED -> { delivered = true; invalidOnly = false; }
                case INVALID_TOKEN -> tokens.revokeIfCurrent(token.id(), token.tokenHash(), now);
                case RETRYABLE_FAILURE -> { retryable = true; invalidOnly = false; }
                case PERMANENT_FAILURE -> invalidOnly = false;
            }
        }

        if (delivered) dispatch.markSent(item, now, null);
        else if (invalidOnly) dispatch.markSent(item, now, failureCode);
        else if (retryable && item.attempts() < MAX_ATTEMPTS)
            dispatch.retry(item, now, now.plus(retryDelay(item.attempts())), failureCode);
        else dispatch.fail(item, now,
                    retryable ? "PUSH_MAX_ATTEMPTS" : failureCode);
        return true;
    }

    static Duration retryDelay(int attempts) {
        long seconds = Math.min(5L << Math.min(Math.max(attempts - 1, 0), 20), MAX_RETRY_DELAY.toSeconds());
        return Duration.ofSeconds(seconds);
    }
}
