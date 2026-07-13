package com.p2pchat.modules.push.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.push.data.DevicePushTokenRepository;

@Service
public class PushRegistrationService {
    private final DeviceRepository devices;
    private final DevicePushTokenRepository tokens;
    private final PushTokenCipher cipher;

    public PushRegistrationService(DeviceRepository devices, DevicePushTokenRepository tokens,
            PushTokenCipher cipher) {
        this.devices = devices; this.tokens = tokens; this.cipher = cipher;
    }

    @Transactional
    public void register(UUID userId, UUID deviceId, PushProvider provider, String token) {
        var device = devices.findById(deviceId).filter(d -> !d.isRevoked())
                .orElseThrow(PushRegistrationService::unavailable);
        if (!device.getUser().getId().equals(userId)) throw unavailable();
        Instant now = Instant.now();
        String hash = hash(token);
        String encrypted = cipher.encrypt(deviceId, provider, token);
        var sameToken = tokens.findByProviderAndTokenHash(provider, hash);
        if (sameToken.isPresent() && !sameToken.get().getDevice().getId().equals(deviceId)) {
            if (!sameToken.get().getDevice().getUser().getId().equals(userId)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "PUSH_TOKEN_ALREADY_REGISTERED");
            }
            tokens.delete(sameToken.get());
            tokens.flush();
        }
        var existing = tokens.findByDeviceIdAndProvider(deviceId, provider);
        if (existing.isPresent()) existing.get().updateToken(encrypted, hash, now);
        else tokens.save(new DevicePushToken(UUID.randomUUID(), device, provider, encrypted, hash, now));
    }

    @Transactional
    public void revoke(UUID userId, UUID deviceId, PushProvider provider) {
        if (!devices.existsByIdAndUserIdAndRevokedAtIsNull(deviceId, userId)) throw unavailable();
        tokens.findByDeviceIdAndProvider(deviceId, provider).ifPresent(token -> token.revoke(Instant.now()));
    }

    private static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private static ResponseStatusException unavailable() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "PUSH_DEVICE_UNAVAILABLE");
    }
}
