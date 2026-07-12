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
    @Autowired TokenService tokens;

    @Test
    void authenticatedDevicesRelayOfferAndServerSetsSenderIdentity() throws Exception {
        Instant now = Instant.now();
        User a = users.save(new User(UUID.randomUUID(), null, "A", now));
        User b = users.save(new User(UUID.randomUUID(), null, "B", now));
        Device da = devices.save(new Device(UUID.randomUUID(), a, "A phone", "pk-a", "fp-" + UUID.randomUUID(), now));
        Device db = devices.save(new Device(UUID.randomUUID(), b, "B phone", "pk-b", "fp-" + UUID.randomUUID(), now));
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

    private WebSocket connect(QueueListener listener) {
        return HttpClient.newHttpClient().newWebSocketBuilder().connectTimeout(Duration.ofSeconds(5))
                .buildAsync(URI.create("ws://localhost:" + port + "/ws/signaling"), listener).join();
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
