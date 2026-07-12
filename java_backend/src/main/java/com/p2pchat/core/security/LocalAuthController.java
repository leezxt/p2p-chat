package com.p2pchat.core.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import com.p2pchat.modules.users.data.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

@Profile({"local", "test"})
@RestController
@RequestMapping("/api/v1/auth")
public class LocalAuthController {
    private final TokenService tokens;
    private final UserRepository users;
    private final byte[] expectedDevKey;

    public LocalAuthController(TokenService tokens, UserRepository users,
            @Value("${app.security.local-dev-key}") String devKey) {
        this.tokens = tokens; this.users = users;
        this.expectedDevKey = devKey.getBytes(StandardCharsets.UTF_8);
    }

    @PostMapping("/local-token")
    public TokenService.AccessToken issue(@RequestHeader("X-Local-Dev-Key") String suppliedKey,
            @Valid @RequestBody TokenRequest request) {
        if (!MessageDigest.isEqual(expectedDevKey, suppliedKey.getBytes(StandardCharsets.UTF_8)))
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        if (!users.existsById(request.userId())) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        return tokens.issue(request.userId());
    }

    public record TokenRequest(@NotNull UUID userId) {}
}
