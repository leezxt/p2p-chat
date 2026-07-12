package com.p2pchat.modules.push.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.devices.domain.Device;
import jakarta.persistence.*;

@Entity
@Table(name = "notification_outbox", uniqueConstraints = @UniqueConstraint(
        name = "uq_outbox_mailbox_event", columnNames = {"mailbox_message_id", "event_type"}))
public class NotificationOutbox {
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

    protected NotificationOutbox() {}

    public NotificationOutbox(UUID id, UUID mailboxMessageId, Device recipientDevice, Instant now) {
        this.id = id; this.mailboxMessageId = mailboxMessageId; this.recipientDevice = recipientDevice;
        this.eventType = "MAILBOX_AVAILABLE";
        this.payloadJson = "{\"schemaVersion\":1,\"type\":\"MAILBOX_AVAILABLE\"}";
        this.state = "PENDING"; this.attempts = 0; this.createdAt = now; this.updatedAt = now;
    }

    public UUID getMailboxMessageId() { return mailboxMessageId; }
    public Device getRecipientDevice() { return recipientDevice; }
    public String getEventType() { return eventType; }
    public String getPayloadJson() { return payloadJson; }
    public String getState() { return state; }
}
