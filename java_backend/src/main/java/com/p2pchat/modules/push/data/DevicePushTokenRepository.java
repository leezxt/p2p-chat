package com.p2pchat.modules.push.data;

import java.util.Optional;
import java.util.List;
import java.util.UUID;
import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import com.p2pchat.modules.push.domain.DevicePushToken;
import com.p2pchat.modules.push.domain.PushProvider;

public interface DevicePushTokenRepository extends JpaRepository<DevicePushToken, UUID> {
    Optional<DevicePushToken> findByDeviceIdAndProvider(UUID deviceId, PushProvider provider);
    Optional<DevicePushToken> findByProviderAndTokenHash(PushProvider provider, String tokenHash);
    List<DevicePushToken> findByDeviceIdAndRevokedAtIsNull(UUID deviceId);
    long deleteByRevokedAtBefore(Instant cutoff);
}
