package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import java.net.URI;
import java.net.http.*;
import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import com.p2pchat.core.security.TokenService;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.contacts.domain.Contact;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import com.p2pchat.modules.push.data.NotificationOutboxRepository;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MailboxApiIntegrationTest {
    private static final Pattern MAILBOX_ID = Pattern.compile("\\\"mailboxMessageId\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"");
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired ContactRepository contacts;
    @Autowired TokenService tokens;
    @Autowired NotificationOutboxRepository outbox;

    @Test
    void encryptedUploadPullAckAndSenderStatusAreAuthorizedAndIdempotent() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Instant now = Instant.now();
        User alice = users.save(new User(UUID.randomUUID(), "mb-a-" + suffix, "Alice", now));
        User bob = users.save(new User(UUID.randomUUID(), "mb-b-" + suffix, "Bob", now));
        Device a = devices.save(new Device(UUID.randomUUID(), alice, "Phone A", "pk-a", "mb-fp-a-" + suffix, now));
        Device b = devices.save(new Device(UUID.randomUUID(), bob, "Phone B", "pk-b", "mb-fp-b-" + suffix, now));
        contacts.save(new Contact(UUID.randomUUID(), alice, bob, null, now));
        contacts.save(new Contact(UUID.randomUUID(), bob, alice, null, now));
        String aliceToken = tokens.issue(alice.getId()).token();
        String bobToken = tokens.issue(bob.getId()).token();
        String nonce = Base64.getUrlEncoder().withoutPadding().encodeToString(new byte[24]);
        String ciphertext = Base64.getUrlEncoder().withoutPadding().encodeToString(new byte[16]);
        String body = "{\"schemaVersion\":1,\"expiresInSeconds\":3600,\"envelope\":{" +
                "\"cryptoVersion\":1,\"suite\":\"P2P_BOX_V1\",\"senderDeviceId\":\"" + a.getId() +
                "\",\"recipientDeviceId\":\"" + b.getId() + "\",\"senderKeyId\":\"key-a\"," +
                "\"recipientKeyId\":\"key-b\",\"messageId\":\"message-" + suffix + "\"," +
                "\"nonce\":\"" + nonce + "\",\"ciphertext\":\"" + ciphertext + "\"}}";
        HttpClient client = HttpClient.newHttpClient();

        var created = send(client, "POST", "/api/v1/mailbox/messages", aliceToken, body);
        assertThat(created.statusCode()).isEqualTo(201);
        var idMatch = MAILBOX_ID.matcher(created.body());
        assertThat(idMatch.find()).isTrue();
        String mailboxId = idMatch.group(1);
        var notification = outbox.findByMailboxMessageIdAndEventType(UUID.fromString(mailboxId), "MAILBOX_AVAILABLE")
                .orElseThrow();
        assertThat(notification.getPayloadJson()).isEqualTo("{\"schemaVersion\":1,\"type\":\"MAILBOX_AVAILABLE\"}")
                .doesNotContain("message-", ciphertext, "Alice", "Bob");
        assertThat(send(client, "POST", "/api/v1/mailbox/messages", aliceToken, body).statusCode()).isEqualTo(200);
        assertThat(outbox.findAll().stream().filter(item -> item.getMailboxMessageId().equals(UUID.fromString(mailboxId))).count())
                .isEqualTo(1);

        var unauthorizedPull = send(client, "GET", "/api/v1/mailbox/messages?deviceId=" + b.getId(), aliceToken, null);
        assertThat(unauthorizedPull.statusCode()).isEqualTo(404);
        var pulled = send(client, "GET", "/api/v1/mailbox/messages?deviceId=" + b.getId(), bobToken, null);
        assertThat(pulled.statusCode()).isEqualTo(200);
        assertThat(pulled.body()).contains(mailboxId, ciphertext).doesNotContain("plaintext");

        String ack = "{\"schemaVersion\":1,\"mailboxMessageId\":\"" + mailboxId +
                "\",\"messageId\":\"message-" + suffix + "\",\"acknowledgingDeviceId\":\"" + b.getId() +
                "\",\"status\":\"DELIVERED\",\"occurredAt\":100}";
        assertThat(send(client, "PUT", "/api/v1/mailbox/messages/" + mailboxId + "/ack", bobToken, ack).statusCode())
                .isEqualTo(200);
        assertThat(send(client, "PUT", "/api/v1/mailbox/messages/" + mailboxId + "/ack", bobToken, ack).statusCode())
                .isEqualTo(200);
        var afterAck = send(client, "GET", "/api/v1/mailbox/messages?deviceId=" + b.getId(), bobToken, null);
        assertThat(afterAck.body()).doesNotContain(mailboxId, ciphertext);
        var senderAcks = send(client, "GET", "/api/v1/mailbox/acks?deviceId=" + a.getId(), aliceToken, null);
        assertThat(senderAcks.body()).contains(mailboxId, "DELIVERED").doesNotContain(ciphertext);
    }

    private HttpResponse<String> send(HttpClient client, String method, String path, String token, String body)
            throws Exception {
        var builder = HttpRequest.newBuilder(uri(path)).header("Authorization", "Bearer " + token);
        if (body != null) builder.header("Content-Type", "application/json");
        builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
        return client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }
    private URI uri(String path) { return URI.create("http://localhost:" + port + path); }
}
