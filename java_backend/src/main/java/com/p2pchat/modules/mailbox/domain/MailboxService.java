package com.p2pchat.modules.mailbox.domain;

import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.mailbox.data.MailboxMessageRepository;
import com.p2pchat.modules.push.domain.NotificationOutboxService;

@Service
public class MailboxService {
    public static final int MAX_CIPHERTEXT_BYTES = 1024 * 1024;
    public static final int MAX_PENDING_MESSAGES = 1000;
    public static final long MAX_PENDING_BYTES = 100L * 1024 * 1024;
    private static final Duration DEFAULT_TTL = Duration.ofDays(7);
    private static final Duration MIN_TTL = Duration.ofHours(1);
    private static final Duration MAX_TTL = Duration.ofDays(30);
    private final MailboxMessageRepository messages;
    private final DeviceRepository devices;
    private final ContactRepository contacts;
    private final MailboxRateLimiter rateLimiter;
    private final NotificationOutboxService notifications;
    private final Clock clock;

    @Autowired
    public MailboxService(MailboxMessageRepository messages, DeviceRepository devices,
            ContactRepository contacts, MailboxRateLimiter rateLimiter, NotificationOutboxService notifications) {
        this(messages, devices, contacts, rateLimiter, notifications, Clock.systemUTC());
    }

    MailboxService(MailboxMessageRepository messages, DeviceRepository devices,
            ContactRepository contacts, MailboxRateLimiter rateLimiter,
            NotificationOutboxService notifications, Clock clock) {
        this.messages = messages; this.devices = devices; this.contacts = contacts;
        this.rateLimiter = rateLimiter; this.notifications = notifications; this.clock = clock;
    }

    @Transactional
    public StoredResult store(UUID userId, Upload upload) {
        rateLimiter.checkUpload(upload.senderDeviceId());
        if (!devices.existsByIdAndUserIdAndRevokedAtIsNull(upload.senderDeviceId(), userId))
            throw unavailable();
        var sender = devices.findById(upload.senderDeviceId()).orElseThrow(MailboxService::unavailable);
        var recipient = devices.findById(upload.recipientDeviceId()).filter(d -> !d.isRevoked())
                .orElseThrow(MailboxService::unavailable);
        if (contacts.findByOwnerIdAndContactUserId(sender.getUser().getId(), recipient.getUser().getId()).isEmpty())
            throw unavailable();
        byte[] ciphertext;
        byte[] nonce;
        try {
            ciphertext = Base64.getUrlDecoder().decode(pad(upload.ciphertext()));
            nonce = Base64.getUrlDecoder().decode(pad(upload.nonce()));
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_ENVELOPE");
        }
        if (nonce.length != 24 || ciphertext.length < 16 || ciphertext.length > MAX_CIPHERTEXT_BYTES)
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "MAILBOX_MESSAGE_TOO_LARGE");
        var existing = messages.findBySenderDeviceIdAndMessageId(upload.senderDeviceId(), upload.messageId());
        if (existing.isPresent()) {
            if (!existing.get().samePayload(upload.nonce(), upload.ciphertext(), upload.recipientDeviceId()))
                throw new ResponseStatusException(HttpStatus.CONFLICT, "MAILBOX_IDEMPOTENCY_CONFLICT");
            return result(existing.get(), false);
        }
        if (messages.countByRecipientDeviceIdAndState(recipient.getId(), MailboxState.STORED) >= MAX_PENDING_MESSAGES
                || messages.pendingBytes(recipient.getId(), MailboxState.STORED) + ciphertext.length > MAX_PENDING_BYTES)
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "MAILBOX_QUOTA_EXCEEDED");
        Duration ttl = upload.expiresInSeconds() == null ? DEFAULT_TTL : Duration.ofSeconds(upload.expiresInSeconds());
        if (ttl.compareTo(MIN_TTL) < 0 || ttl.compareTo(MAX_TTL) > 0)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_TTL");
        Instant now = clock.instant();
        var message = messages.save(new MailboxMessage(UUID.randomUUID(), upload.messageId(), sender, recipient,
                upload.senderKeyId(), upload.recipientKeyId(), upload.nonce(), upload.ciphertext(),
                ciphertext.length, now, now.plus(ttl)));
        notifications.enqueue(message);
        return result(message, true);
    }

    @Transactional(readOnly = true)
    public PullPage pull(UUID userId, UUID deviceId, UUID cursor, int limit) {
        rateLimiter.checkReadOrAck(deviceId);
        requireOwnedDevice(userId, deviceId);
        var all = messages.findByRecipientDeviceIdAndStateOrderByStoredAtAscIdAsc(deviceId, MailboxState.STORED);
        int start = 0;
        if (cursor != null) {
            while (start < all.size() && !all.get(start).getId().equals(cursor)) start++;
            if (start == all.size())
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_CURSOR");
            start++;
        }
        int pageSize = Math.min(Math.max(limit, 1), 100);
        int end = Math.min(start + pageSize, all.size());
        var items = List.copyOf(all.subList(start, end));
        UUID nextCursor = end < all.size() && !items.isEmpty() ? items.get(items.size() - 1).getId() : null;
        return new PullPage(items, nextCursor);
    }

    @Transactional
    public MailboxMessage acknowledge(UUID userId, UUID id, UUID deviceId, MailboxState status) {
        rateLimiter.checkReadOrAck(deviceId);
        requireOwnedDevice(userId, deviceId);
        if (status != MailboxState.DELIVERED && status != MailboxState.READ)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_ACK");
        var message = messages.findById(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "MAILBOX_MESSAGE_NOT_FOUND"));
        if (!message.getRecipientDevice().getId().equals(deviceId)) throw unavailable();
        try { message.acknowledge(status, clock.instant()); }
        catch (IllegalStateException e) { throw new ResponseStatusException(HttpStatus.CONFLICT, e.getMessage()); }
        return message;
    }

    @Transactional(readOnly = true)
    public List<MailboxMessage> senderStatuses(UUID userId, UUID deviceId, int limit) {
        rateLimiter.checkReadOrAck(deviceId);
        requireOwnedDevice(userId, deviceId);
        return messages.findBySenderDeviceIdOrderByUpdatedAtAscIdAsc(deviceId).stream()
                .limit(Math.min(Math.max(limit, 1), 100)).toList();
    }

    @Scheduled(fixedDelayString = "${app.mailbox.cleanup-delay:PT1H}")
    @Transactional
    public void expireMessages() {
        Instant now = clock.instant();
        messages.findByStateAndExpiresAtBefore(MailboxState.STORED, now).forEach(message -> message.expire(now));
    }

    private void requireOwnedDevice(UUID userId, UUID deviceId) {
        if (!devices.existsByIdAndUserIdAndRevokedAtIsNull(deviceId, userId)) throw unavailable();
    }
    private StoredResult result(MailboxMessage message, boolean created) {
        return new StoredResult(message.getId(), message.getMessageId(), message.getState(),
                message.getStoredAt(), message.getExpiresAt(), created);
    }
    private static ResponseStatusException unavailable() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "MAILBOX_TARGET_UNAVAILABLE");
    }
    private static String pad(String value) { return value + "=".repeat((4 - value.length() % 4) % 4); }

    public record Upload(String messageId, UUID senderDeviceId, UUID recipientDeviceId,
            String senderKeyId, String recipientKeyId, String nonce, String ciphertext, Long expiresInSeconds) {}
    public record StoredResult(UUID mailboxMessageId, String messageId, MailboxState status,
            Instant storedAt, Instant expiresAt, boolean created) {}
    public record PullPage(List<MailboxMessage> items, UUID nextCursor) {}
}
