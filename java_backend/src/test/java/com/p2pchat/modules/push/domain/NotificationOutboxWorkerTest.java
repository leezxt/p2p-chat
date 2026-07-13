package com.p2pchat.modules.push.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayDeque;
import java.util.List;
import java.util.UUID;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.mailbox.data.MailboxMessageRepository;
import com.p2pchat.modules.mailbox.domain.MailboxMessage;
import com.p2pchat.modules.push.data.DevicePushTokenRepository;
import com.p2pchat.modules.push.data.NotificationOutboxRepository;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest
class NotificationOutboxWorkerTest {
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired MailboxMessageRepository messages;
    @Autowired NotificationOutboxRepository outbox;
    @Autowired DevicePushTokenRepository pushTokens;
    @Autowired NotificationOutboxService outboxService;
    @Autowired NotificationOutboxDispatchService dispatch;
    @Autowired PushRegistrationService registrations;
    @Autowired PushTokenDeliveryService tokenDelivery;
    @Autowired JdbcTemplate jdbc;

    @BeforeEach
    void clearOutbox() {
        outbox.deleteAll();
    }

    @Test
    void successfulDeliverySendsOnlyTheOpaqueMailboxSignal() {
        var clock = clock();
        var fixture = fixture(clock.instant(), true);
        var gateway = new FakeGateway(PushDeliveryResult.delivered());

        assertThat(worker(clock, gateway).dispatchOne()).isTrue();

        var stored = outbox.findById(fixture.outboxId()).orElseThrow();
        assertThat(stored.getState()).isEqualTo("SENT");
        assertThat(stored.getAttempts()).isEqualTo(1);
        assertThat(gateway.tokens).containsExactly(fixture.providerToken());
        assertThat(gateway.notifications).singleElement().satisfies(notification ->
                assertThat(notification.data()).containsExactlyInAnyOrderEntriesOf(
                        java.util.Map.of("schemaVersion", "1", "type", "MAILBOX_AVAILABLE")));
    }

    @Test
    void missingTokenCompletesWithoutCallingAProvider() {
        var clock = clock();
        var fixture = fixture(clock.instant(), false);
        var gateway = new FakeGateway(PushDeliveryResult.delivered());

        worker(clock, gateway).dispatchOne();

        var stored = outbox.findById(fixture.outboxId()).orElseThrow();
        assertThat(stored.getState()).isEqualTo("SENT");
        assertThat(stored.getLastErrorCode()).isEqualTo("PUSH_NO_ACTIVE_TOKEN");
        assertThat(gateway.tokens).isEmpty();
    }

    @Test
    void transientFailureUsesBoundedBackoffAndThenSucceeds() {
        var clock = clock();
        var fixture = fixture(clock.instant(), true);
        var gateway = new FakeGateway(
                PushDeliveryResult.retryable("FCM_UNAVAILABLE"), PushDeliveryResult.delivered());
        var worker = worker(clock, gateway);

        worker.dispatchOne();
        var pending = outbox.findById(fixture.outboxId()).orElseThrow();
        assertThat(pending.getState()).isEqualTo("PENDING");
        assertThat(pending.getAttempts()).isEqualTo(1);
        assertThat(pending.getNextAttemptAt()).isEqualTo(clock.instant().plusSeconds(5));
        assertThat(worker.dispatchOne()).isFalse();

        clock.advance(Duration.ofSeconds(5));
        assertThat(worker.dispatchOne()).isTrue();
        assertThat(outbox.findById(fixture.outboxId()).orElseThrow().getState()).isEqualTo("SENT");
        assertThat(outbox.findById(fixture.outboxId()).orElseThrow().getAttempts()).isEqualTo(2);
    }

    @Test
    void unregisteredTokenIsRevokedAndCiphertextIsCleared() {
        var clock = clock();
        var fixture = fixture(clock.instant(), true);
        var token = pushTokens.findByDeviceIdAndProvider(fixture.recipientDeviceId(), PushProvider.FCM)
                .orElseThrow();
        var gateway = new FakeGateway(PushDeliveryResult.invalidToken("FCM_UNREGISTERED"));

        worker(clock, gateway).dispatchOne();

        assertThat(outbox.findById(fixture.outboxId()).orElseThrow().getState()).isEqualTo("SENT");
        assertThat(pushTokens.findById(token.getId()).orElseThrow().isRevoked()).isTrue();
        assertThat(jdbc.queryForObject(
                "SELECT token_ciphertext IS NULL FROM device_push_tokens WHERE id = ?",
                Boolean.class, token.getId())).isTrue();
    }

    @Test
    void staleUnregisteredResponseDoesNotRevokeANewerToken() {
        var clock = clock();
        var fixture = fixture(clock.instant(), true);
        String replacementToken = "replacement-" + fixture.providerToken();
        PushGateway gateway = new PushGateway() {
            @Override
            public PushProvider provider() {
                return PushProvider.FCM;
            }

            @Override
            public PushDeliveryResult send(String token, PushNotification notification) {
                try {
                    registrations.register(fixture.recipientUserId(), fixture.recipientDeviceId(),
                            PushProvider.FCM, replacementToken);
                } catch (RuntimeException exception) {
                    throw new AssertionError("Replacement token registration failed", exception);
                }
                return PushDeliveryResult.invalidToken("FCM_UNREGISTERED");
            }
        };

        worker(clock, gateway).dispatchOne();

        var current = pushTokens.findByDeviceIdAndProvider(fixture.recipientDeviceId(), PushProvider.FCM)
                .orElseThrow();
        assertThat(outbox.findById(fixture.outboxId()).orElseThrow().getState()).isEqualTo("SENT");
        assertThat(current.isRevoked()).isFalse();
        assertThat(tokenDelivery.activeTokens(fixture.recipientDeviceId())).singleElement()
                .satisfies(token -> assertThat(token.token()).isEqualTo(replacementToken));
    }

    @Test
    void permanentFailureAndTamperedPayloadAreNotRetried() {
        var clock = clock();
        var permanent = fixture(clock.instant(), true);
        var gateway = new FakeGateway(PushDeliveryResult.permanent("FCM_SENDER_ID_MISMATCH"));
        worker(clock, gateway).dispatchOne();
        assertThat(outbox.findById(permanent.outboxId()).orElseThrow().getState()).isEqualTo("FAILED");

        var tampered = fixture(clock.instant().plusSeconds(1), true);
        jdbc.update("UPDATE notification_outbox SET payload_json = ? WHERE id = ?",
                "{\"schemaVersion\":1,\"type\":\"MAILBOX_AVAILABLE\",\"sender\":\"secret\"}",
                tampered.outboxId());
        clock.advance(Duration.ofSeconds(2));
        int callsBefore = gateway.tokens.size();
        worker(clock, gateway).dispatchOne();
        var rejected = outbox.findById(tampered.outboxId()).orElseThrow();
        assertThat(rejected.getState()).isEqualTo("FAILED");
        assertThat(rejected.getLastErrorCode()).isEqualTo("PUSH_PAYLOAD_INVALID");
        assertThat(gateway.tokens).hasSize(callsBefore);
    }

    @Test
    void retryStopsAfterTheEighthAttempt() {
        var clock = clock();
        var fixture = fixture(clock.instant(), true);
        var gateway = new FakeGateway(PushDeliveryResult.retryable("FCM_UNAVAILABLE"));
        var worker = worker(clock, gateway);

        for (int attempt = 1; attempt <= NotificationOutboxWorker.MAX_ATTEMPTS; attempt++) {
            assertThat(worker.dispatchOne()).isTrue();
            if (attempt < NotificationOutboxWorker.MAX_ATTEMPTS)
                clock.advance(NotificationOutboxWorker.retryDelay(attempt));
        }

        var failed = outbox.findById(fixture.outboxId()).orElseThrow();
        assertThat(failed.getState()).isEqualTo("FAILED");
        assertThat(failed.getAttempts()).isEqualTo(NotificationOutboxWorker.MAX_ATTEMPTS);
        assertThat(failed.getLastErrorCode()).isEqualTo("PUSH_MAX_ATTEMPTS");
    }

    @Test
    void expiredLeaseCanBeReclaimedAndStaleWorkerCannotCompleteIt() {
        var clock = clock();
        fixture(clock.instant(), false);

        var first = dispatch.claimNext(clock.instant(), Duration.ofMinutes(2)).orElseThrow();
        assertThat(dispatch.claimNext(clock.instant().plusSeconds(1), Duration.ofMinutes(2))).isEmpty();

        var second = dispatch.claimNext(clock.instant().plusSeconds(121), Duration.ofMinutes(2)).orElseThrow();
        assertThat(second.outboxId()).isEqualTo(first.outboxId());
        assertThat(second.attempts()).isEqualTo(2);
        assertThat(dispatch.markSent(first, clock.instant().plusSeconds(122), null)).isFalse();
        assertThat(dispatch.markSent(second, clock.instant().plusSeconds(122), null)).isTrue();
    }

    private NotificationOutboxWorker worker(MutableClock clock, PushGateway gateway) {
        return new NotificationOutboxWorker(dispatch, tokenDelivery, List.of(gateway), clock, 50);
    }

    private Fixture fixture(Instant now, boolean registerToken) {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        User sender = users.save(new User(UUID.randomUUID(), "worker-a-" + suffix, "Sender", now));
        User recipient = users.save(new User(UUID.randomUUID(), "worker-b-" + suffix, "Recipient", now));
        Device senderDevice = devices.save(new Device(UUID.randomUUID(), sender,
                "Sender phone", "pk-a", "worker-fp-a-" + suffix, now));
        Device recipientDevice = devices.save(new Device(UUID.randomUUID(), recipient,
                "Recipient phone", "pk-b", "worker-fp-b-" + suffix, now));
        String providerToken = "provider-token-" + suffix;
        if (registerToken)
            registrations.register(recipient.getId(), recipientDevice.getId(), PushProvider.FCM, providerToken);
        var message = messages.save(new MailboxMessage(UUID.randomUUID(), "message-" + suffix,
                senderDevice, recipientDevice, "key-a", "key-b", "nonce", "ciphertext",
                16, now, now.plus(Duration.ofDays(7))));
        outboxService.enqueue(message);
        UUID outboxId = outbox.findByMailboxMessageIdAndEventType(
                message.getId(), NotificationOutbox.EVENT_MAILBOX_AVAILABLE).orElseThrow().getId();
        return new Fixture(outboxId, recipient.getId(), recipientDevice.getId(), providerToken);
    }

    private static MutableClock clock() {
        return new MutableClock(Instant.now().plusSeconds(5).truncatedTo(ChronoUnit.SECONDS));
    }

    private record Fixture(UUID outboxId, UUID recipientUserId,
            UUID recipientDeviceId, String providerToken) {}

    private static final class FakeGateway implements PushGateway {
        private final ArrayDeque<PushDeliveryResult> results = new ArrayDeque<>();
        private final java.util.ArrayList<String> tokens = new java.util.ArrayList<>();
        private final java.util.ArrayList<PushNotification> notifications = new java.util.ArrayList<>();

        private FakeGateway(PushDeliveryResult... results) {
            this.results.addAll(List.of(results));
        }

        @Override
        public PushProvider provider() {
            return PushProvider.FCM;
        }

        @Override
        public PushDeliveryResult send(String token, PushNotification notification) {
            tokens.add(token);
            notifications.add(notification);
            if (results.size() > 1) return results.removeFirst();
            return results.getFirst();
        }
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
}
