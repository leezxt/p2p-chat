package com.p2pchat.modules.push.presentation;

import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import com.p2pchat.modules.push.domain.PushProvider;
import com.p2pchat.modules.push.domain.PushRegistrationService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/v1/push/devices")
public class PushRegistrationController {
    private final PushRegistrationService service;
    public PushRegistrationController(PushRegistrationService service) { this.service = service; }

    @PutMapping("/{deviceId}/token")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID deviceId,
            @Valid @RequestBody TokenRequest request) {
        service.register(UUID.fromString(jwt.getSubject()), deviceId, request.provider(), request.token());
    }

    @DeleteMapping("/{deviceId}/token/{provider}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID deviceId,
            @PathVariable PushProvider provider) {
        service.revoke(UUID.fromString(jwt.getSubject()), deviceId, provider);
    }

    public record TokenRequest(@NotNull PushProvider provider, @NotBlank @Size(max = 4096) String token) {}
}
