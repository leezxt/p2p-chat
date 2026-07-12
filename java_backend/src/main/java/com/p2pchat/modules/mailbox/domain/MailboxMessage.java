package com.p2pchat.modules.mailbox.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.devices.domain.Device;
import jakarta.persistence.*;

@Entity
@Table(name = "mailbox_messages", uniqueConstraints = @UniqueConstraint(
        name = "uq_mailbox_sender_message", columnNames = {"sender_device_id", "message_id"}))
public class MailboxMessage {
    @Id private UUID id;
    @Column(name = "message_id", nullable = false, length = 256) private String messageId;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_device_id", nullable = false) private Device senderDevice;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipient_device_id", nullable = false) private Device recipientDevice;
    @Column(name = "sender_key_id", nullable = false, length = 256) private String senderKeyId;
    @Column(name = "recipient_key_id", nullable = false, length = 256) private String recipientKeyId;
    @Column(nullable = false, length = 64) private String nonce;
    @Column(columnDefinition = "TEXT") private String ciphertext;
    @Column(name = "ciphertext_bytes", nullable = false) private int ciphertextBytes;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 16) private MailboxState state;
    @Column(name = "stored_at", nullable = false) private Instant storedAt;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @Column(name = "delivered_at") private Instant deliveredAt;
    @Column(name = "read_at") private Instant readAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected MailboxMessage() {}

    public MailboxMessage(UUID id, String messageId, Device senderDevice, Device recipientDevice,
            String senderKeyId, String recipientKeyId, String nonce, String ciphertext,
            int ciphertextBytes, Instant storedAt, Instant expiresAt) {
        this.id = id; this.messageId = messageId; this.senderDevice = senderDevice;
        this.recipientDevice = recipientDevice; this.senderKeyId = senderKeyId;
        this.recipientKeyId = recipientKeyId; this.nonce = nonce; this.ciphertext = ciphertext;
        this.ciphertextBytes = ciphertextBytes; this.state = MailboxState.STORED;
        this.storedAt = storedAt; this.expiresAt = expiresAt; this.updatedAt = storedAt;
    }

    public UUID getId() { return id; }
    public String getMessageId() { return messageId; }
    public Device getSenderDevice() { return senderDevice; }
    public Device getRecipientDevice() { return recipientDevice; }
    public String getSenderKeyId() { return senderKeyId; }
    public String getRecipientKeyId() { return recipientKeyId; }
    public String getNonce() { return nonce; }
    public String getCiphertext() { return ciphertext; }
    public int getCiphertextBytes() { return ciphertextBytes; }
    public MailboxState getState() { return state; }
    public Instant getStoredAt() { return storedAt; }
    public Instant getExpiresAt() { return expiresAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public boolean samePayload(String nonce, String ciphertext, UUID recipientId) {
        return this.nonce.equals(nonce) && java.util.Objects.equals(this.ciphertext, ciphertext)
                && recipientDevice.getId().equals(recipientId);
    }

    public void acknowledge(MailboxState requested, Instant now) {
        if (requested == state) return;
        if (state == MailboxState.STORED && requested == MailboxState.DELIVERED) {
            state = requested; deliveredAt = now; ciphertext = null; updatedAt = now; return;
        }
        if (state == MailboxState.DELIVERED && requested == MailboxState.READ) {
            state = requested; readAt = now; updatedAt = now; return;
        }
        throw new IllegalStateException("MAILBOX_INVALID_STATE_TRANSITION");
    }

    public void expire(Instant now) {
        if (state != MailboxState.STORED) return;
        state = MailboxState.EXPIRED; ciphertext = null; updatedAt = now;
    }
}
