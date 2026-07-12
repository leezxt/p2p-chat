package com.p2pchat.modules.devices.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.users.domain.User;
import jakarta.persistence.*;

@Entity
@Table(name = "devices")
public class Device {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    @Column(nullable = false, length = 100) private String name;
    @Column(name = "public_key", nullable = false, columnDefinition = "TEXT") private String publicKey;
    @Column(name = "public_key_fingerprint", nullable = false, unique = true, length = 128)
    private String publicKeyFingerprint;
    @Column(name = "revoked_at") private Instant revokedAt;
    @Column(name = "last_seen_at") private Instant lastSeenAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected Device() {}

    public Device(UUID id, User user, String name, String publicKey, String fingerprint, Instant now) {
        this.id = id; this.user = user; this.name = name; this.publicKey = publicKey;
        this.publicKeyFingerprint = fingerprint; this.createdAt = now; this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public User getUser() { return user; }
    public String getName() { return name; }
    public String getPublicKey() { return publicKey; }
    public String getPublicKeyFingerprint() { return publicKeyFingerprint; }
    public boolean isRevoked() { return revokedAt != null; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getLastSeenAt() { return lastSeenAt; }

    public boolean canInitializeKey(String fingerprint) {
        return publicKey.startsWith("pending:") || publicKeyFingerprint.equals(fingerprint);
    }

    public void initializeKey(String publicKey, String fingerprint, Instant now) {
        this.publicKey = publicKey;
        this.publicKeyFingerprint = fingerprint;
        this.updatedAt = now;
    }

    public void touchPresence(Instant now) {
        this.lastSeenAt = now;
        this.updatedAt = now;
    }
}
