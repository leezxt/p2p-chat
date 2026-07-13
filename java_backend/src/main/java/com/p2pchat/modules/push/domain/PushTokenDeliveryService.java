package com.p2pchat.modules.push.domain;

import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.p2pchat.modules.push.data.DevicePushTokenRepository;

@Service
public class PushTokenDeliveryService {
    private final DevicePushTokenRepository tokens;
    private final PushTokenCipher cipher;

    public PushTokenDeliveryService(DevicePushTokenRepository tokens, PushTokenCipher cipher) {
        this.tokens = tokens; this.cipher = cipher;
    }

    @Transactional(readOnly = true)
    public List<DeliveryToken> activeTokens(UUID deviceId) {
        return tokens.findByDeviceIdAndRevokedAtIsNull(deviceId).stream()
                .map(token -> new DeliveryToken(token.getProvider(), token.decrypt(cipher))).toList();
    }

    public record DeliveryToken(PushProvider provider, String token) {}
}
