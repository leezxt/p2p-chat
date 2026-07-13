package com.p2pchat.modules.push.domain;

import static org.assertj.core.api.Assertions.*;

import java.security.SecureRandom;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class PushTokenCipherTest {
    private static final String KEY_A = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=";
    private static final String KEY_B = "ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj8=";
    private final UUID deviceId = UUID.randomUUID();

    @Test
    void roundTripDoesNotExposePlaintext() {
        var cipher = cipher("current=" + KEY_A);
        String encrypted = cipher.encrypt(deviceId, PushProvider.FCM, "provider-secret-token");

        assertThat(encrypted).startsWith("v1.current.").doesNotContain("provider-secret-token");
        assertThat(cipher.decrypt(deviceId, PushProvider.FCM, encrypted)).isEqualTo("provider-secret-token");
    }

    @Test
    void ciphertextIsBoundToDeviceAndProvider() {
        var cipher = cipher("current=" + KEY_A);
        String encrypted = cipher.encrypt(deviceId, PushProvider.FCM, "token");

        assertThatThrownBy(() -> cipher.decrypt(UUID.randomUUID(), PushProvider.FCM, encrypted))
                .hasMessage("PUSH_TOKEN_DECRYPTION_FAILED");
        assertThatThrownBy(() -> cipher.decrypt(deviceId, PushProvider.APNS, encrypted))
                .hasMessage("PUSH_TOKEN_DECRYPTION_FAILED");
    }

    @Test
    void tamperedCiphertextIsRejected() {
        var cipher = cipher("current=" + KEY_A);
        String encrypted = cipher.encrypt(deviceId, PushProvider.FCM, "token");
        String tampered = encrypted.substring(0, encrypted.length() - 1)
                + (encrypted.endsWith("A") ? "B" : "A");

        assertThatThrownBy(() -> cipher.decrypt(deviceId, PushProvider.FCM, tampered))
                .hasMessage("PUSH_TOKEN_DECRYPTION_FAILED");
    }

    @Test
    void rotatedKeyRingReadsOldCiphertextAndWritesWithNewKey() {
        String oldEnvelope = cipher("old=" + KEY_A).encrypt(deviceId, PushProvider.FCM, "token");
        var rotated = cipher("new=" + KEY_B + ",old=" + KEY_A);

        assertThat(rotated.decrypt(deviceId, PushProvider.FCM, oldEnvelope)).isEqualTo("token");
        assertThat(rotated.encrypt(deviceId, PushProvider.FCM, "new-token")).startsWith("v1.new.");
    }

    @Test
    void invalidKeyRingIsRejected() {
        assertThatThrownBy(() -> cipher("bad=YWJj"))
                .hasMessage("Push token encryption keys must be 32 bytes");
        assertThatThrownBy(() -> cipher("missing-separator"))
                .hasMessage("Invalid push token encryption key ring");
    }

    @Test
    void missingKeyRingFailsClosed() {
        assertThatThrownBy(() -> new PushTokenCipher(new MockEnvironment()))
                .hasMessage("Push token encryption key ring is required");
    }

    private PushTokenCipher cipher(String keys) {
        return new PushTokenCipher(keys, new SecureRandom());
    }
}
