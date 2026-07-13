package com.p2pchat.modules.mailbox.presentation;

import java.time.Instant;
import java.util.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import com.p2pchat.modules.mailbox.domain.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

@RestController
@RequestMapping("/api/v1/mailbox")
public class MailboxController {
    private final MailboxService service;
    public MailboxController(MailboxService service) { this.service = service; }

    @PostMapping("/messages")
    public ResponseEntity<StoredResponse> upload(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UploadRequest request) {
        var e = request.envelope();
        if (request.schemaVersion() != 1 || e.cryptoVersion() != 1 || !"P2P_BOX_V1".equals(e.suite()))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "MAILBOX_INVALID_ENVELOPE");
        var result = service.store(UUID.fromString(jwt.getSubject()), new MailboxService.Upload(
                e.messageId(), e.senderDeviceId(), e.recipientDeviceId(), e.senderKeyId(),
                e.recipientKeyId(), e.nonce(), e.ciphertext(), request.expiresInSeconds()));
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(new StoredResponse(result.mailboxMessageId(), result.messageId(), result.status(),
                        result.storedAt(), result.expiresAt()));
    }

    @GetMapping("/messages")
    public PageResponse pull(@AuthenticationPrincipal Jwt jwt, @RequestParam UUID deviceId,
            @RequestParam(required = false) UUID cursor, @RequestParam(defaultValue = "50") int limit) {
        var page = service.pull(UUID.fromString(jwt.getSubject()), deviceId, cursor, limit);
        var items = page.items().stream()
                .map(m -> new MessageResponse(m.getId(), m.getStoredAt(), m.getExpiresAt(),
                        new EnvelopeResponse(1, "P2P_BOX_V1", m.getSenderDevice().getId(),
                                m.getRecipientDevice().getId(), m.getSenderKeyId(), m.getRecipientKeyId(),
                                m.getMessageId(), m.getNonce(), m.getCiphertext())))
                .toList();
        return new PageResponse(items, page.nextCursor() == null ? null : page.nextCursor().toString());
    }

    @PutMapping("/messages/{id}/ack")
    public AckResponse ack(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody AckRequest request) {
        if (request.schemaVersion() != 1 || !id.equals(request.mailboxMessageId()))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_ACK");
        var message = service.acknowledge(UUID.fromString(jwt.getSubject()), id,
                request.messageId(), request.acknowledgingDeviceId(), request.status());
        return new AckResponse(message.getId(), message.getMessageId(), message.getState(), message.getUpdatedAt());
    }

    @GetMapping("/acks")
    public List<AckResponse> acks(@AuthenticationPrincipal Jwt jwt, @RequestParam UUID deviceId,
            @RequestParam(defaultValue = "50") int limit) {
        return service.senderStatuses(UUID.fromString(jwt.getSubject()), deviceId, limit).stream()
                .map(m -> new AckResponse(m.getId(), m.getMessageId(), m.getState(), m.getUpdatedAt())).toList();
    }

    public record UploadRequest(@NotNull Integer schemaVersion, @Positive Long expiresInSeconds,
            @NotNull @Valid EnvelopeRequest envelope) {}
    public record EnvelopeRequest(int cryptoVersion, @NotBlank String suite, @NotNull UUID senderDeviceId,
            @NotNull UUID recipientDeviceId, @NotBlank @Size(max=256) String senderKeyId,
            @NotBlank @Size(max=256) String recipientKeyId, @NotBlank @Size(max=256) String messageId,
            @NotBlank @Size(max=64) String nonce, @NotBlank @Size(max=1500000) String ciphertext) {}
    public record StoredResponse(UUID mailboxMessageId, String messageId, MailboxState status,
            Instant storedAt, Instant expiresAt) {}
    public record EnvelopeResponse(int cryptoVersion, String suite, UUID senderDeviceId, UUID recipientDeviceId,
            String senderKeyId, String recipientKeyId, String messageId, String nonce, String ciphertext) {}
    public record MessageResponse(UUID mailboxMessageId, Instant storedAt, Instant expiresAt, EnvelopeResponse envelope) {}
    public record PageResponse(List<MessageResponse> items, String nextCursor) {}
    public record AckRequest(@NotNull Integer schemaVersion, @NotNull UUID mailboxMessageId,
            @NotBlank String messageId, @NotNull UUID acknowledgingDeviceId, @NotNull MailboxState status,
            @Positive long occurredAt) {}
    public record AckResponse(UUID mailboxMessageId, String messageId, MailboxState status, Instant acceptedAt) {}
}
