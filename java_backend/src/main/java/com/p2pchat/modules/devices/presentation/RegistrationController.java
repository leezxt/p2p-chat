package com.p2pchat.modules.devices.presentation;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.core.security.TokenService;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

@Profile({"local", "test"})
@RestController
@RequestMapping("/api/v1/registration")
public class RegistrationController {
    private final UserRepository users;
    private final DeviceRepository devices;
    private final TokenService tokens;
    private final byte[] expectedDevKey;

    public RegistrationController(UserRepository users, DeviceRepository devices, TokenService tokens,
            @Value("${app.security.local-dev-key}") String devKey) {
        this.users = users; this.devices = devices; this.tokens = tokens;
        this.expectedDevKey = devKey.getBytes(StandardCharsets.UTF_8);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public RegistrationResponse register(@RequestHeader("X-Local-Dev-Key") String suppliedKey,
            @Valid @RequestBody RegistrationRequest request) {
        if (!MessageDigest.isEqual(expectedDevKey, suppliedKey.getBytes(StandardCharsets.UTF_8)))
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        if (users.existsById(request.userId()) || devices.existsById(request.deviceId()))
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Identity already registered");
        Instant now = Instant.now();
        User user = users.save(new User(request.userId(), null, request.displayName(), now));
        devices.save(new Device(request.deviceId(), user, request.deviceName(), request.publicKey(),
                request.publicKeyFingerprint(), now));
        var token = tokens.issue(user.getId());
        return new RegistrationResponse(user.getId(), request.deviceId(), token.token(), token.expiresAt());
    }

    public record RegistrationRequest(@NotNull UUID userId, @NotNull UUID deviceId,
            @NotBlank @Size(max=100) String displayName, @NotBlank @Size(max=100) String deviceName,
            @NotBlank @Size(max=512) String publicKey,
            @NotBlank @Size(max=128) String publicKeyFingerprint) {}
    public record RegistrationResponse(UUID userId, UUID deviceId, String accessToken, Instant expiresAt) {}
}
