package com.p2pchat.modules.contacts.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.users.domain.User;
import jakarta.persistence.*;

@Entity
@Table(name = "invite_codes")
public class InviteCode {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "inviter_user_id", nullable = false) private User inviter;
    @Column(name = "code_hash", nullable = false, unique = true, length = 64) private String codeHash;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "redeemed_by_user_id") private User redeemedBy;
    @Column(name = "redeemed_at") private Instant redeemedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected InviteCode() {}

    public InviteCode(UUID id, User inviter, String codeHash, Instant expiresAt, Instant createdAt) {
        this.id = id; this.inviter = inviter; this.codeHash = codeHash;
        this.expiresAt = expiresAt; this.createdAt = createdAt;
    }

    public UUID getId() { return id; }
    public User getInviter() { return inviter; }
    public Instant getExpiresAt() { return expiresAt; }
    public void redeem(User user, Instant now) {
        if (redeemedAt != null) throw new IllegalStateException("Invite code has already been redeemed");
        if (!now.isBefore(expiresAt)) throw new IllegalStateException("Invite code has expired");
        if (inviter.getId().equals(user.getId())) throw new IllegalArgumentException("Cannot redeem your own invite code");
        redeemedBy = user; redeemedAt = now;
    }
}
