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
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.contacts.domain.Contact;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class PresenceApiIntegrationTest {
    @Value("${local.server.port}") int port;
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired ContactRepository contacts;
    @Autowired TokenService tokens;

    @Test
    void heartbeatRequiresDeviceOwnershipAndContactsAreAclScoped() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Instant now = Instant.now();
        User alice = users.save(new User(UUID.randomUUID(), "pr-a-" + suffix, "Alice", now));
        User bob = users.save(new User(UUID.randomUUID(), "pr-b-" + suffix, "Bob", now));
        User eve = users.save(new User(UUID.randomUUID(), "pr-e-" + suffix, "Eve", now));
        Device a = devices.save(new Device(UUID.randomUUID(), alice, "Phone A", "pk-a", "pr-fp-a-" + suffix, now));
        Device b = devices.save(new Device(UUID.randomUUID(), bob, "Phone B", "pk-b", "pr-fp-b-" + suffix, now));
        devices.save(new Device(UUID.randomUUID(), eve, "Phone E", "pk-e", "pr-fp-e-" + suffix, now));
        contacts.save(new Contact(UUID.randomUUID(), alice, bob, null, now));
        String aliceToken = tokens.issue(alice.getId()).token();
        String bobToken = tokens.issue(bob.getId()).token();
        HttpClient client = HttpClient.newHttpClient();

        assertThat(send(client, "POST", "/api/v1/presence/" + b.getId() + "/heartbeat", aliceToken).statusCode())
                .isEqualTo(403);
        assertThat(send(client, "POST", "/api/v1/presence/" + b.getId() + "/heartbeat", bobToken).statusCode())
                .isEqualTo(204);

        var result = send(client, "GET", "/api/v1/presence/contacts", aliceToken);
        assertThat(result.statusCode()).isEqualTo(200);
        assertThat(result.body()).contains(bob.getId().toString(), b.getId().toString(), "lastSeenAt")
                .doesNotContain(eve.getId().toString(), a.getId().toString());
    }

    private HttpResponse<String> send(HttpClient client, String method, String path, String token) throws Exception {
        var request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Authorization", "Bearer " + token)
                .method(method, HttpRequest.BodyPublishers.noBody()).build();
        return client.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
