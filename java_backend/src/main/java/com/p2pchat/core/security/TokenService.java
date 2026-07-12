package com.p2pchat.core.security;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;

@Service
public class TokenService {
    private final JwtEncoder encoder;
    private final String issuer;
    private final String audience;
    private final Duration ttl;
    private final Clock clock = Clock.systemUTC();

    public TokenService(JwtEncoder encoder,
            @Value("${app.security.jwt.issuer}") String issuer,
            @Value("${app.security.jwt.audience}") String audience,
            @Value("${app.security.jwt.ttl}") Duration ttl) {
        this.encoder = encoder; this.issuer = issuer; this.audience = audience; this.ttl = ttl;
    }

    public AccessToken issue(UUID userId) {
        Instant now = clock.instant();
        JwtClaimsSet claims = JwtClaimsSet.builder().issuer(issuer).subject(userId.toString())
                .audience(List.of(audience)).issuedAt(now).expiresAt(now.plus(ttl))
                .id(UUID.randomUUID().toString()).build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).type("JWT").build();
        Jwt jwt = encoder.encode(JwtEncoderParameters.from(header, claims));
        return new AccessToken(jwt.getTokenValue(), jwt.getExpiresAt());
    }

    public record AccessToken(String token, Instant expiresAt) {}
}
