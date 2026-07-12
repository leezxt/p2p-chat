package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import java.net.URI;
import java.net.http.*;
import java.util.UUID;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class RegistrationApiIntegrationTest {
    private static final Pattern TOKEN = Pattern.compile("\\\"accessToken\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"");
    @Value("${local.server.port}") int port;

    @Test
    void registrationReturnsTokenThatCanOnlyListOwnDevices() throws Exception {
        UUID user = UUID.randomUUID(); UUID device = UUID.randomUUID();
        String json = "{\"userId\":\"" + user + "\",\"deviceId\":\"" + device
                + "\",\"displayName\":\"Alice\",\"deviceName\":\"Phone\","
                + "\"publicKey\":\"pending:" + device + "\","
                + "\"publicKeyFingerprint\":\"pending:" + device + "\"}";
        HttpClient client = HttpClient.newHttpClient();
        var registered = client.send(HttpRequest.newBuilder(uri("/api/v1/registration"))
                .header("X-Local-Dev-Key", "test-local-dev-key").header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json)).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(registered.statusCode()).isEqualTo(201);
        var duplicate = client.send(HttpRequest.newBuilder(uri("/api/v1/registration"))
                .header("X-Local-Dev-Key", "test-local-dev-key").header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json)).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(duplicate.statusCode()).isEqualTo(409);
        var token = TOKEN.matcher(registered.body()); assertThat(token.find()).isTrue();
        String keyJson = "{\"publicKey\":\"real-public-key-" + device
                + "\",\"publicKeyFingerprint\":\"real-fingerprint-" + device + "\"}";
        var initialized = client.send(HttpRequest.newBuilder(uri("/api/v1/devices/" + device + "/key"))
                .header("Authorization", "Bearer " + token.group(1)).header("Content-Type", "application/json")
                .PUT(HttpRequest.BodyPublishers.ofString(keyJson)).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(initialized.statusCode()).isEqualTo(204);
        var listed = client.send(HttpRequest.newBuilder(uri("/api/v1/devices"))
                .header("Authorization", "Bearer " + token.group(1)).GET().build(), HttpResponse.BodyHandlers.ofString());
        assertThat(listed.statusCode()).isEqualTo(200);
        assertThat(listed.body()).contains(device.toString()).contains("real-public-key-").doesNotContain("private");
    }
    private URI uri(String path) { return URI.create("http://localhost:" + port + path); }
}
