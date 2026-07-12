package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import java.net.URI;
import java.net.http.*;
import java.time.Instant;
import java.util.UUID;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import com.p2pchat.core.security.TokenService;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class InviteApiIntegrationTest {
    private static final Pattern CODE = Pattern.compile("\\\"code\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"");
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired ContactRepository contacts;
    @Autowired TokenService tokens;
    @Autowired DeviceRepository devices;

    @Test
    void authenticatedUsersCreateAndRedeemInviteThroughHttpApi() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        User alice = users.save(new User(UUID.randomUUID(), "api-a-" + suffix, "Alice", Instant.now()));
        User bob = users.save(new User(UUID.randomUUID(), "api-b-" + suffix, "Bob", Instant.now()));
        devices.save(new Device(UUID.randomUUID(), alice, "Phone", "pk-a", "fp-" + suffix, Instant.now()));
        String aliceToken = tokens.issue(alice.getId()).token();
        String bobToken = tokens.issue(bob.getId()).token();
        HttpClient client = HttpClient.newHttpClient();

        HttpResponse<String> created = client.send(HttpRequest.newBuilder(uri("/api/v1/invites"))
                .header("Authorization", "Bearer " + aliceToken)
                .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(created.statusCode()).isEqualTo(201);
        var match = CODE.matcher(created.body());
        assertThat(match.find()).isTrue();

        HttpResponse<String> redeemed = client.send(HttpRequest.newBuilder(uri("/api/v1/invites/redeem"))
                .header("Authorization", "Bearer " + bobToken).header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString("{\"code\":\"" + match.group(1) + "\"}"))
                .build(), HttpResponse.BodyHandlers.ofString());
        assertThat(redeemed.statusCode()).isEqualTo(200);
        assertThat(redeemed.body()).contains(alice.getId().toString(), "Alice");
        assertThat(contacts.findByOwnerIdAndContactUserId(alice.getId(), bob.getId())).isPresent();
    }

    private URI uri(String path) { return URI.create("http://localhost:" + port + path); }
}
