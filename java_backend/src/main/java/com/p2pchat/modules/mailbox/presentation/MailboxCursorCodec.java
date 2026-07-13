package com.p2pchat.modules.mailbox.presentation;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class MailboxCursorCodec {
    private static final byte VERSION = 1;
    private static final int PAYLOAD_BYTES = 34;
    private static final int MAC_BYTES = 32;
    private static final int TOKEN_BYTES = PAYLOAD_BYTES + MAC_BYTES;
    private static final String ALGORITHM = "HmacSHA256";
    private static final byte[] KEY_CONTEXT = "p2p-chat/mailbox-cursor/v1".getBytes(StandardCharsets.UTF_8);

    private final SecretKey cursorKey;

    public MailboxCursorCodec(SecretKey jwtSecretKey) {
        this.cursorKey = new SecretKeySpec(hmac(jwtSecretKey, KEY_CONTEXT), ALGORITHM);
    }

    public enum Purpose {
        INBOX((byte) 1), ACKS((byte) 2);
        private final byte value;
        Purpose(byte value) { this.value = value; }
    }

    public String encode(Purpose purpose, UUID deviceId, UUID mailboxMessageId) {
        ByteBuffer payload = ByteBuffer.allocate(PAYLOAD_BYTES);
        payload.put(VERSION);
        payload.put(purpose.value);
        putUuid(payload, deviceId);
        putUuid(payload, mailboxMessageId);
        byte[] payloadBytes = payload.array();
        byte[] token = ByteBuffer.allocate(TOKEN_BYTES)
                .put(payloadBytes)
                .put(hmac(cursorKey, payloadBytes))
                .array();
        return Base64.getUrlEncoder().withoutPadding().encodeToString(token);
    }

    public UUID decode(String token, Purpose expectedPurpose, UUID expectedDeviceId) {
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(token);
            if (decoded.length != TOKEN_BYTES) throw invalid();
            byte[] payload = java.util.Arrays.copyOfRange(decoded, 0, PAYLOAD_BYTES);
            byte[] suppliedMac = java.util.Arrays.copyOfRange(decoded, PAYLOAD_BYTES, TOKEN_BYTES);
            if (!MessageDigest.isEqual(suppliedMac, hmac(cursorKey, payload))) throw invalid();
            ByteBuffer buffer = ByteBuffer.wrap(payload);
            if (buffer.get() != VERSION) throw invalid();
            if (buffer.get() != expectedPurpose.value) throw invalid();
            UUID deviceId = getUuid(buffer);
            UUID mailboxMessageId = getUuid(buffer);
            if (!deviceId.equals(expectedDeviceId) || buffer.hasRemaining()) throw invalid();
            return mailboxMessageId;
        } catch (IllegalArgumentException e) {
            throw invalid();
        }
    }

    private static byte[] hmac(SecretKey key, byte[] value) {
        try {
            Mac mac = Mac.getInstance(ALGORITHM);
            mac.init(key);
            return mac.doFinal(value);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC-SHA256 is unavailable", e);
        }
    }

    private static void putUuid(ByteBuffer buffer, UUID value) {
        buffer.putLong(value.getMostSignificantBits()).putLong(value.getLeastSignificantBits());
    }

    private static UUID getUuid(ByteBuffer buffer) {
        return new UUID(buffer.getLong(), buffer.getLong());
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, "MAILBOX_INVALID_CURSOR");
    }
}
