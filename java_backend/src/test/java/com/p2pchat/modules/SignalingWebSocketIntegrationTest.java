package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.*;
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

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SignalingWebSocketIntegrationTest {
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired ContactRepository contacts;
    @Autowired TokenService tokens;

    @Test
    void authenticatedDevicesRelayOfferAndServerSetsSenderIdentity() throws Exception {
        Instant now = Instant.now();
        User a = users.save(new User(UUID.randomUUID(), null, "A", now));
        User b = users.save(new User(UUID.randomUUID(), null, "B", now));
        Device da = devices.save(new Device(UUID.randomUUID(), a, "A phone", "pk-a", "fp-" + UUID.randomUUID(), now));
        Device db = devices.save(new Device(UUID.randomUUID(), b, "B phone", "pk-b", "fp-" + UUID.randomUUID(), now));
        contacts.save(new Contact(UUID.randomUUID(), a, b, null, now));
        QueueListener la = new QueueListener(); QueueListener lb = new QueueListener();
        WebSocket wa = connect(la); WebSocket wb = connect(lb);
        try {
            wa.sendText(auth(da.getId(), tokens.issue(a.getId()).token()), true).join();
            wb.sendText(auth(db.getId(), tokens.issue(b.getId()).token()), true).join();
            assertThat(la.next()).contains("AUTHENTICATED");
            assertThat(lb.next()).contains("AUTHENTICATED");
            String sessionId = UUID.randomUUID().toString();
            wa.sendText("{\"schemaVersion\":1,\"type\":\"OFFER\",\"sessionId\":\"" + sessionId
                    + "\",\"targetDeviceId\":\"" + db.getId() + "\",\"payload\":{\"sdp\":\"offer-sdp\"}}", true).join();
            String relayed = lb.next();
            assertThat(relayed).contains("\"type\":\"OFFER\"", sessionId, da.getId().toString(), "offer-sdp");
        } finally {
            wa.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            wb.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
        }
    }

    @Test
    void signalingRejectsRelayToNonContactWithoutDisclosingAvailability() throws Exception {
        Instant now = Instant.now();
        User sender = users.save(new User(UUID.randomUUID(), null, "Sender", now));
        User target = users.save(new User(UUID.randomUUID(), null, "Target", now));
        Device senderDevice = devices.save(new Device(UUID.randomUUID(), sender, "Sender phone", "pk-s",
                "fp-" + UUID.randomUUID(), now));
        Device targetDevice = devices.save(new Device(UUID.randomUUID(), target, "Target phone", "pk-t",
                "fp-" + UUID.randomUUID(), now));
        QueueListener senderListener = new QueueListener(); QueueListener targetListener = new QueueListener();
        WebSocket senderSocket = connect(senderListener); WebSocket targetSocket = connect(targetListener);
        try {
            senderSocket.sendText(auth(senderDevice.getId(), tokens.issue(sender.getId()).token()), true).join();
            targetSocket.sendText(auth(targetDevice.getId(), tokens.issue(target.getId()).token()), true).join();
            assertThat(senderListener.next()).contains("AUTHENTICATED");
            assertThat(targetListener.next()).contains("AUTHENTICATED");
            senderSocket.sendText("{\"schemaVersion\":1,\"type\":\"OFFER\",\"sessionId\":\"blocked\""
                    + ",\"targetDeviceId\":\"" + targetDevice.getId() + "\",\"payload\":{\"sdp\":\"offer\"}}",
                    true).join();
            assertThat(senderListener.next()).contains("TARGET_UNAVAILABLE");
            assertThat(targetListener.messages.poll(200, TimeUnit.MILLISECONDS)).isNull();
        } finally {
            senderSocket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            targetSocket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
        }
    }

    @Test
    void signalingAllowsConfiguredOrigin() {
        WebSocket socket = connect(new QueueListener(), "https://allowed.example.test");
        socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
    }

    @Test
    void signalingRejectsUnlistedOrigin() {
        try {
            connect(new QueueListener(), "https://blocked.example.test");
            throw new AssertionError("Expected WebSocket handshake rejection");
        } catch (CompletionException exception) {
            assertThat(exception.getCause()).isInstanceOf(WebSocketHandshakeException.class);
            var handshake = (WebSocketHandshakeException) exception.getCause();
            assertThat(handshake.getResponse().statusCode()).isEqualTo(403);
        }
    }

    private WebSocket connect(QueueListener listener) {
        return connect(listener, null);
    }
    private WebSocket connect(QueueListener listener, String origin) {
        var builder = HttpClient.newHttpClient().newWebSocketBuilder().connectTimeout(Duration.ofSeconds(5));
        if (origin != null) builder.header("Origin", origin);
        return builder.buildAsync(URI.create("ws://localhost:" + port + "/ws/signaling"), listener).join();
    }
    private String auth(UUID device, String token) {
        return "{\"schemaVersion\":1,\"type\":\"AUTH\",\"deviceId\":\"" + device + "\",\"token\":\"" + token + "\"}";
    }
    private static class QueueListener implements WebSocket.Listener {
        final BlockingQueue<String> messages = new LinkedBlockingQueue<>();
        final StringBuilder current = new StringBuilder();
        @Override public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            current.append(data); if (last) { messages.add(current.toString()); current.setLength(0); }
            webSocket.request(1); return null;
        }
        @Override public void onOpen(WebSocket webSocket) { webSocket.request(1); }
        String next() throws InterruptedException {
            String value = messages.poll(5, TimeUnit.SECONDS);
            assertThat(value).as("WebSocket message").isNotNull(); return value;
        }
    }
}
