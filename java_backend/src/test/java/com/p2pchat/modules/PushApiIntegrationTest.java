package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import java.net.URI;
import java.net.http.*;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import com.p2pchat.core.security.TokenService;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.push.data.DevicePushTokenRepository;
import com.p2pchat.modules.push.domain.PushProvider;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class PushApiIntegrationTest {
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired DevicePushTokenRepository pushTokens;
    @Autowired TokenService tokens;

    @Test
    void tokenRegistrationUpdateAndRevokeRequireDeviceOwnership() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Instant now = Instant.now();
        User alice = users.save(new User(UUID.randomUUID(), "push-a-" + suffix, "Alice", now));
        User bob = users.save(new User(UUID.randomUUID(), "push-b-" + suffix, "Bob", now));
        Device device = devices.save(new Device(UUID.randomUUID(), alice, "Phone", "pk", "push-fp-" + suffix, now));
        Device bobDevice = devices.save(new Device(UUID.randomUUID(), bob, "Phone B", "pk-b", "push-fp-b-" + suffix, now));
        String aliceToken = tokens.issue(alice.getId()).token();
        String bobToken = tokens.issue(bob.getId()).token();
        HttpClient client = HttpClient.newHttpClient();
        String path = "/api/v1/push/devices/" + device.getId() + "/token";

        assertThat(send(client, "PUT", path, bobToken, "{\"provider\":\"FCM\",\"token\":\"secret-a\"}").statusCode())
                .isEqualTo(404);
        assertThat(send(client, "PUT", path, aliceToken, "{\"provider\":\"FCM\",\"token\":\"secret-a\"}").statusCode())
                .isEqualTo(204);
        var stored = pushTokens.findByDeviceIdAndProvider(device.getId(), PushProvider.FCM).orElseThrow();
        String firstHash = stored.getTokenHash();

        assertThat(send(client, "PUT", path, aliceToken, "{\"provider\":\"FCM\",\"token\":\"secret-b\"}").statusCode())
                .isEqualTo(204);
        stored = pushTokens.findByDeviceIdAndProvider(device.getId(), PushProvider.FCM).orElseThrow();
        assertThat(stored.getTokenHash()).isNotEqualTo(firstHash);
        assertThat(stored.isRevoked()).isFalse();

        String bobPath = "/api/v1/push/devices/" + bobDevice.getId() + "/token";
        assertThat(send(client, "PUT", bobPath, bobToken, "{\"provider\":\"FCM\",\"token\":\"secret-b\"}").statusCode())
                .isEqualTo(409);

        assertThat(send(client, "DELETE", path + "/FCM", aliceToken, null).statusCode()).isEqualTo(204);
        assertThat(pushTokens.findByDeviceIdAndProvider(device.getId(), PushProvider.FCM).orElseThrow().isRevoked())
                .isTrue();
    }

    private HttpResponse<String> send(HttpClient client, String method, String path, String token, String body)
            throws Exception {
        var builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Authorization", "Bearer " + token);
        if (body != null) builder.header("Content-Type", "application/json");
        builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
        return client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }
}
