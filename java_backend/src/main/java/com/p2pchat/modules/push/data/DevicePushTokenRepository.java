package com.p2pchat.modules.push.data;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.p2pchat.modules.push.domain.DevicePushToken;
import com.p2pchat.modules.push.domain.PushProvider;

public interface DevicePushTokenRepository extends JpaRepository<DevicePushToken, UUID> {
    Optional<DevicePushToken> findByDeviceIdAndProvider(UUID deviceId, PushProvider provider);
    Optional<DevicePushToken> findByProviderAndTokenHash(PushProvider provider, String tokenHash);
}
