package com.p2pchat.modules.push.domain;

import java.time.Instant;
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
                .map(token -> new DeliveryToken(token.getId(), token.getProvider(), token.getTokenHash(),
                        token.decrypt(cipher))).toList();
    }

    @Transactional
    public boolean revokeIfCurrent(UUID tokenId, String tokenHash, Instant now) {
        return tokens.findById(tokenId).filter(token -> !token.isRevoked())
                .filter(token -> token.getTokenHash().equals(tokenHash))
                .map(token -> { token.revoke(now); return true; }).orElse(false);
    }

    public record DeliveryToken(UUID id, PushProvider provider, String tokenHash, String token) {}
}
