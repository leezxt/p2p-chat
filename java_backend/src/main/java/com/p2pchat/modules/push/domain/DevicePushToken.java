package com.p2pchat.modules.push.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.devices.domain.Device;
import jakarta.persistence.*;

@Entity
@Table(name = "device_push_tokens", uniqueConstraints = {
        @UniqueConstraint(name = "uq_push_token_device_provider", columnNames = {"device_id", "provider"}),
        @UniqueConstraint(name = "uq_push_token_provider_hash", columnNames = {"provider", "token_hash"})})
public class DevicePushToken {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "device_id", nullable = false) private Device device;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 16) private PushProvider provider;
    @Column(nullable = false, columnDefinition = "TEXT") private String token;
    @Column(name = "token_hash", nullable = false, length = 64) private String tokenHash;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "revoked_at") private Instant revokedAt;

    protected DevicePushToken() {}

    public DevicePushToken(UUID id, Device device, PushProvider provider, String token, String tokenHash, Instant now) {
        this.id = id; this.device = device; this.provider = provider; this.token = token;
        this.tokenHash = tokenHash; this.createdAt = now; this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public Device getDevice() { return device; }
    public PushProvider getProvider() { return provider; }
    public String getTokenHash() { return tokenHash; }
    public boolean isRevoked() { return revokedAt != null; }

    public void updateToken(String token, String tokenHash, Instant now) {
        this.token = token; this.tokenHash = tokenHash; this.revokedAt = null; this.updatedAt = now;
    }

    public void revoke(Instant now) { this.revokedAt = now; this.updatedAt = now; }
}
