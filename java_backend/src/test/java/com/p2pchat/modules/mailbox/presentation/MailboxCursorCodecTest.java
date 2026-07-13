package com.p2pchat.modules.mailbox.presentation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.charset.StandardCharsets;
import java.util.UUID;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class MailboxCursorCodecTest {
    private final MailboxCursorCodec codec = new MailboxCursorCodec(new SecretKeySpec(
            "test-cursor-secret-at-least-32-bytes".getBytes(StandardCharsets.UTF_8), "HmacSHA256"));

    @Test
    void cursorRoundTripsWithoutExposingIdentifiers() {
        UUID deviceId = UUID.randomUUID();
        UUID mailboxMessageId = UUID.randomUUID();
        String token = codec.encode(MailboxCursorCodec.Purpose.INBOX, deviceId, mailboxMessageId);

        assertThat(token).doesNotContain(deviceId.toString(), mailboxMessageId.toString());
        assertThat(codec.decode(token, MailboxCursorCodec.Purpose.INBOX, deviceId)).isEqualTo(mailboxMessageId);
    }

    @Test
    void tamperedOrCrossDeviceCursorIsRejected() {
        UUID deviceId = UUID.randomUUID();
        String token = codec.encode(MailboxCursorCodec.Purpose.INBOX, deviceId, UUID.randomUUID());
        char replacement = token.charAt(token.length() - 1) == 'A' ? 'B' : 'A';
        String tampered = token.substring(0, token.length() - 1) + replacement;

        assertInvalid(tampered, deviceId);
        assertInvalid(token, UUID.randomUUID());
        assertInvalid("not-a-valid-cursor", deviceId);
        assertThatThrownBy(() -> codec.decode(token, MailboxCursorCodec.Purpose.ACKS, deviceId))
                .isInstanceOf(ResponseStatusException.class);
    }

    private void assertInvalid(String token, UUID deviceId) {
        assertThatThrownBy(() -> codec.decode(token, MailboxCursorCodec.Purpose.INBOX, deviceId))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> {
                    ResponseStatusException response = (ResponseStatusException) error;
                    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(response.getReason()).isEqualTo("MAILBOX_INVALID_CURSOR");
                });
    }
}
