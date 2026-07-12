package com.p2pchat.modules.devices.presentation;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.modules.devices.data.DeviceRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/v1/devices")
public class DeviceController {
    private final DeviceRepository devices;
    public DeviceController(DeviceRepository devices) { this.devices = devices; }

    @GetMapping
    public List<DeviceResponse> listOwn(@AuthenticationPrincipal Jwt jwt) {
        UUID userId = UUID.fromString(jwt.getSubject());
        return devices.findByUserIdAndRevokedAtIsNull(userId).stream()
                .map(d -> new DeviceResponse(d.getId(), d.getName(), d.getPublicKey(), d.getPublicKeyFingerprint()))
                .toList();
    }

    @PutMapping("/{deviceId}/key")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void initializeKey(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID deviceId,
            @Valid @RequestBody InitializeKeyRequest request) {
        UUID userId = UUID.fromString(jwt.getSubject());
        var device = devices.findById(deviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        if (!device.getUser().getId().equals(userId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        if (device.isRevoked())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Device is revoked");
        if (!device.canInitializeKey(request.publicKeyFingerprint()))
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Key rotation requires verification flow");
        device.initializeKey(request.publicKey(), request.publicKeyFingerprint(), Instant.now());
    }

    public record DeviceResponse(UUID id, String name, String publicKey, String publicKeyFingerprint) {}
    public record InitializeKeyRequest(@NotBlank @Size(max=512) String publicKey,
            @NotBlank @Size(max=128) String publicKeyFingerprint) {}
}
