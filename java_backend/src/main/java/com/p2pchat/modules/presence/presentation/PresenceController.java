package com.p2pchat.modules.presence.presentation;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.devices.data.DeviceRepository;

@RestController
@RequestMapping("/api/v1/presence")
public class PresenceController {
    private final DeviceRepository devices;
    private final ContactRepository contacts;

    public PresenceController(DeviceRepository devices, ContactRepository contacts) {
        this.devices = devices;
        this.contacts = contacts;
    }

    @PostMapping("/{deviceId}/heartbeat")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void heartbeat(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID deviceId) {
        UUID userId = UUID.fromString(jwt.getSubject());
        var device = devices.findById(deviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        if (!device.getUser().getId().equals(userId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        if (device.isRevoked())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Device is revoked");
        device.touchPresence(Instant.now());
    }

    @GetMapping("/contacts")
    @Transactional(readOnly = true)
    public List<ContactPresenceResponse> contacts(@AuthenticationPrincipal Jwt jwt) {
        UUID ownerId = UUID.fromString(jwt.getSubject());
        return contacts.findByOwnerId(ownerId).stream().map(contact -> {
            var user = contact.getContactUser();
            var device = devices.findFirstByUserIdAndRevokedAtIsNullOrderByCreatedAtAsc(user.getId())
                    .orElse(null);
            return new ContactPresenceResponse(user.getId(), device == null ? null : device.getId(),
                    device == null ? null : device.getLastSeenAt());
        }).toList();
    }

    public record ContactPresenceResponse(UUID userId, UUID deviceId, Instant lastSeenAt) {}
}
