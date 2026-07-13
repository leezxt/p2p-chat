package com.p2pchat.modules.push.domain;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.*;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class PushTokenCipher {
    private static final String VERSION = "v1";
    private static final int KEY_BYTES = 32;
    private static final int NONCE_BYTES = 12;
    private static final int TAG_BITS = 128;
    private final LinkedHashMap<String, SecretKeySpec> keys;
    private final SecureRandom random;

    @Autowired
    public PushTokenCipher(Environment environment) {
        this(requiredKeyRing(environment), new SecureRandom());
    }

    PushTokenCipher(String configuredKeys, SecureRandom random) {
        this.keys = parseKeys(configuredKeys);
        this.random = random;
    }

    public String encrypt(UUID deviceId, PushProvider provider, String token) {
        var active = keys.entrySet().iterator().next();
        byte[] nonce = new byte[NONCE_BYTES];
        random.nextBytes(nonce);
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, active.getValue(), new GCMParameterSpec(TAG_BITS, nonce));
            cipher.updateAAD(aad(deviceId, provider, active.getKey()));
            byte[] encrypted = cipher.doFinal(token.getBytes(StandardCharsets.UTF_8));
            return String.join(".", VERSION, active.getKey(), encode(nonce), encode(encrypted));
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("PUSH_TOKEN_ENCRYPTION_FAILED", exception);
        }
    }

    public String decrypt(UUID deviceId, PushProvider provider, String envelope) {
        try {
            String[] parts = envelope.split("\\.", -1);
            if (parts.length != 4 || !VERSION.equals(parts[0])) throw new GeneralSecurityException();
            SecretKeySpec key = keys.get(parts[1]);
            if (key == null) throw new GeneralSecurityException();
            byte[] nonce = decode(parts[2]);
            if (nonce.length != NONCE_BYTES) throw new GeneralSecurityException();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, nonce));
            cipher.updateAAD(aad(deviceId, provider, parts[1]));
            return new String(cipher.doFinal(decode(parts[3])), StandardCharsets.UTF_8);
        } catch (GeneralSecurityException | IllegalArgumentException exception) {
            throw new IllegalStateException("PUSH_TOKEN_DECRYPTION_FAILED", exception);
        }
    }

    private static LinkedHashMap<String, SecretKeySpec> parseKeys(String configuredKeys) {
        var result = new LinkedHashMap<String, SecretKeySpec>();
        for (String entry : configuredKeys.split(",")) {
            int separator = entry.indexOf('=');
            if (separator < 1 || separator == entry.length() - 1)
                throw new IllegalStateException("Invalid push token encryption key ring");
            String keyId = entry.substring(0, separator).trim();
            if (!keyId.matches("[A-Za-z0-9_-]{1,32}") || result.containsKey(keyId))
                throw new IllegalStateException("Invalid push token encryption key id");
            byte[] key;
            try { key = Base64.getDecoder().decode(entry.substring(separator + 1).trim()); }
            catch (IllegalArgumentException exception) {
                throw new IllegalStateException("Invalid push token encryption key", exception);
            }
            if (key.length != KEY_BYTES) throw new IllegalStateException("Push token encryption keys must be 32 bytes");
            result.put(keyId, new SecretKeySpec(key, "AES"));
        }
        if (result.isEmpty()) throw new IllegalStateException("Push token encryption key ring is required");
        return result;
    }

    private static String requiredKeyRing(Environment environment) {
        String configured = environment.getProperty("app.security.push-token.encryption-keys");
        if (configured == null || configured.isBlank())
            throw new IllegalStateException("Push token encryption key ring is required");
        return configured;
    }

    private static byte[] aad(UUID deviceId, PushProvider provider, String keyId) {
        return ("PUSH_TOKEN_V1\0" + deviceId + "\0" + provider + "\0" + keyId)
                .getBytes(StandardCharsets.UTF_8);
    }

    private static String encode(byte[] value) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value);
    }

    private static byte[] decode(String value) {
        return Base64.getUrlDecoder().decode(value);
    }
}
