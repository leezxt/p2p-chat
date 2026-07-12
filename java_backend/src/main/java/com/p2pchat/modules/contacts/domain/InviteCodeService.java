package com.p2pchat.modules.contacts.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.contacts.data.InviteCodeRepository;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import com.p2pchat.modules.devices.data.DeviceRepository;

@Service
public class InviteCodeService {
    private static final Duration DEFAULT_TTL = Duration.ofMinutes(15);
    private final SecureRandom random = new SecureRandom();
    private final UserRepository users;
    private final InviteCodeRepository invites;
    private final ContactRepository contacts;
    private final DeviceRepository devices;
    private final Clock clock;

    @Autowired
    public InviteCodeService(UserRepository users, InviteCodeRepository invites, ContactRepository contacts,
            DeviceRepository devices) {
        this(users, invites, contacts, devices, Clock.systemUTC());
    }

    InviteCodeService(UserRepository users, InviteCodeRepository invites, ContactRepository contacts,
            DeviceRepository devices, Clock clock) {
        this.users = users; this.invites = invites; this.contacts = contacts; this.devices = devices; this.clock = clock;
    }

    @Transactional
    public CreatedInvite create(UUID inviterId) {
        User inviter = users.findById(inviterId).orElseThrow(() -> new InviteCodeException("USER_NOT_FOUND"));
        byte[] bytes = new byte[16];
        random.nextBytes(bytes);
        String rawCode = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant now = clock.instant();
        InviteCode invite = new InviteCode(UUID.randomUUID(), inviter, hash(rawCode), now.plus(DEFAULT_TTL), now);
        invites.save(invite);
        return new CreatedInvite(rawCode, invite.getExpiresAt());
    }

    @Transactional
    public RedeemedContact redeem(String rawCode, UUID redeemerId) {
        User redeemer = users.findById(redeemerId).orElseThrow(() -> new InviteCodeException("USER_NOT_FOUND"));
        InviteCode invite = invites.findByCodeHashForUpdate(hash(rawCode))
                .orElseThrow(() -> new InviteCodeException("INVITE_NOT_FOUND"));
        try {
            invite.redeem(redeemer, clock.instant());
        } catch (IllegalStateException e) {
            throw new InviteCodeException(e.getMessage().contains("expired") ? "INVITE_EXPIRED" : "INVITE_ALREADY_REDEEMED");
        } catch (IllegalArgumentException e) {
            throw new InviteCodeException("SELF_REDEMPTION_NOT_ALLOWED");
        }
        User inviter = invite.getInviter();
        createContactIfMissing(inviter, redeemer);
        createContactIfMissing(redeemer, inviter);
        var device = devices.findFirstByUserIdAndRevokedAtIsNullOrderByCreatedAtAsc(inviter.getId())
                .orElseThrow(() -> new InviteCodeException("INVITER_HAS_NO_DEVICE"));
        return new RedeemedContact(inviter.getId(), inviter.getDisplayName(), device.getId(),
                device.getPublicKey(), device.getPublicKeyFingerprint());
    }

    @Transactional(readOnly = true)
    public List<RedeemedContact> listContacts(UUID ownerId) {
        return contacts.findByOwnerId(ownerId).stream().map(contact -> {
            User other = contact.getContactUser();
            var device = devices.findFirstByUserIdAndRevokedAtIsNullOrderByCreatedAtAsc(other.getId())
                    .orElseThrow(() -> new InviteCodeException("CONTACT_HAS_NO_DEVICE"));
            return new RedeemedContact(other.getId(),
                    contact.getAlias() == null ? other.getDisplayName() : contact.getAlias(),
                    device.getId(), device.getPublicKey(), device.getPublicKeyFingerprint());
        }).toList();
    }

    private void createContactIfMissing(User owner, User other) {
        if (contacts.findByOwnerIdAndContactUserId(owner.getId(), other.getId()).isEmpty()) {
            contacts.save(new Contact(UUID.randomUUID(), owner, other, null, clock.instant()));
        }
    }

    private static String hash(String code) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(code.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is unavailable", e);
        }
    }

    public record CreatedInvite(String code, Instant expiresAt) {}
    public record RedeemedContact(UUID userId, String displayName, UUID deviceId,
            String publicKey, String publicKeyFingerprint) {}
}
