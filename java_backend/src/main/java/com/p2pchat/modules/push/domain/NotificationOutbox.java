package com.p2pchat.modules.push.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.devices.domain.Device;
import jakarta.persistence.*;

@Entity
@Table(name = "notification_outbox", uniqueConstraints = @UniqueConstraint(
        name = "uq_outbox_mailbox_event", columnNames = {"mailbox_message_id", "event_type"}))
public class NotificationOutbox {
    public static final String EVENT_MAILBOX_AVAILABLE = "MAILBOX_AVAILABLE";
    public static final String PAYLOAD_MAILBOX_AVAILABLE =
            "{\"schemaVersion\":1,\"type\":\"MAILBOX_AVAILABLE\"}";
    @Id private UUID id;
    @Column(name = "mailbox_message_id", nullable = false) private UUID mailboxMessageId;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipient_device_id", nullable = false) private Device recipientDevice;
    @Column(name = "event_type", nullable = false, length = 32) private String eventType;
    @Column(name = "payload_json", nullable = false, length = 256) private String payloadJson;
    @Column(nullable = false, length = 16) private String state;
    @Column(nullable = false) private int attempts;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "next_attempt_at", nullable = false) private Instant nextAttemptAt;
    @Column(name = "lease_until") private Instant leaseUntil;
    @Column(name = "lease_token") private UUID leaseToken;
    @Column(name = "last_error_code", length = 64) private String lastErrorCode;

    protected NotificationOutbox() {}

    public NotificationOutbox(UUID id, UUID mailboxMessageId, Device recipientDevice, Instant now) {
        this.id = id; this.mailboxMessageId = mailboxMessageId; this.recipientDevice = recipientDevice;
        this.eventType = EVENT_MAILBOX_AVAILABLE;
        this.payloadJson = PAYLOAD_MAILBOX_AVAILABLE;
        this.state = "PENDING"; this.attempts = 0; this.createdAt = now; this.updatedAt = now;
        this.nextAttemptAt = now;
    }

    public UUID getId() { return id; }
    public UUID getMailboxMessageId() { return mailboxMessageId; }
    public Device getRecipientDevice() { return recipientDevice; }
    public String getEventType() { return eventType; }
    public String getPayloadJson() { return payloadJson; }
    public String getState() { return state; }
    public int getAttempts() { return attempts; }
    public Instant getNextAttemptAt() { return nextAttemptAt; }
    public Instant getLeaseUntil() { return leaseUntil; }
    public UUID getLeaseToken() { return leaseToken; }
    public String getLastErrorCode() { return lastErrorCode; }

    void claim(UUID token, Instant now, Instant until) {
        boolean pending = "PENDING".equals(state) && !nextAttemptAt.isAfter(now);
        boolean expiredLease = "PROCESSING".equals(state) && leaseUntil != null && !leaseUntil.isAfter(now);
        if (!pending && !expiredLease) throw new IllegalStateException("PUSH_OUTBOX_NOT_DISPATCHABLE");
        state = "PROCESSING";
        attempts++;
        leaseToken = token;
        leaseUntil = until;
        updatedAt = now;
        lastErrorCode = null;
    }

    boolean markSent(UUID token, Instant now, String resultCode) {
        if (!hasLease(token)) return false;
        state = "SENT";
        nextAttemptAt = now;
        clearLease(now, resultCode);
        return true;
    }

    boolean retry(UUID token, Instant now, Instant retryAt, String errorCode) {
        if (!hasLease(token)) return false;
        state = "PENDING";
        nextAttemptAt = retryAt;
        clearLease(now, errorCode);
        return true;
    }

    boolean fail(UUID token, Instant now, String errorCode) {
        if (!hasLease(token)) return false;
        state = "FAILED";
        nextAttemptAt = now;
        clearLease(now, errorCode);
        return true;
    }

    boolean hasExpectedPayload() {
        return EVENT_MAILBOX_AVAILABLE.equals(eventType) && PAYLOAD_MAILBOX_AVAILABLE.equals(payloadJson);
    }

    private boolean hasLease(UUID token) {
        return "PROCESSING".equals(state) && leaseToken != null && leaseToken.equals(token);
    }

    private void clearLease(Instant now, String errorCode) {
        leaseToken = null;
        leaseUntil = null;
        updatedAt = now;
        lastErrorCode = errorCode;
    }
}
