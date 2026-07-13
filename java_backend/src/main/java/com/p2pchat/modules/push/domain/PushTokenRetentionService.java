package com.p2pchat.modules.push.domain;

import java.time.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.p2pchat.modules.push.data.DevicePushTokenRepository;

@Service
public class PushTokenRetentionService {
    private final DevicePushTokenRepository tokens;
    private final Duration retention;
    private final Clock clock;

    @Autowired
    public PushTokenRetentionService(DevicePushTokenRepository tokens,
            @Value("${app.security.push-token.revoked-retention:P30D}") Duration retention) {
        this(tokens, retention, Clock.systemUTC());
    }

    PushTokenRetentionService(DevicePushTokenRepository tokens, Duration retention, Clock clock) {
        if (retention.isNegative() || retention.isZero())
            throw new IllegalArgumentException("Push token retention must be positive");
        this.tokens = tokens; this.retention = retention; this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${app.security.push-token.cleanup-delay:PT1H}")
    @Transactional
    public long purgeRevoked() {
        return tokens.deleteByRevokedAtBefore(clock.instant().minus(retention));
    }
}
