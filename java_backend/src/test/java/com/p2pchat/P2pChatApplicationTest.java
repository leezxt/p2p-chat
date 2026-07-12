package com.p2pchat;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.boot.health.contributor.Status;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import com.p2pchat.core.security.TokenService;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class P2pChatApplicationTest {

    @Value("${local.server.port}")
    private int port;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired private TokenService tokenService;
    @Autowired private JwtDecoder jwtDecoder;

    @Test
    void applicationStartsAndHealthEndpointIsUp() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "/actuator/health"))
                .GET()
                .build();
        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("\"status\":\"" + Status.UP.getCode() + "\"");
        assertThat(response.body()).doesNotContain("components");
    }

    @Test
    void flywayCreatesSchemaOnEmptyDatabase() {
        String initialized = jdbcTemplate.queryForObject(
                "SELECT metadata_value FROM app_metadata WHERE metadata_key = ?",
                String.class,
                "schema_initialized");
        assertThat(initialized).isEqualTo("true");
    }

    @Test
    void protectedApiRejectsMissingBearerToken() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "/api/v1/invites"))
                .POST(HttpRequest.BodyPublishers.noBody()).build();
        assertThat(HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.discarding()).statusCode())
                .isEqualTo(401);
    }

    @Test
    void issuedTokenContainsValidatedIdentityAndAudience() {
        UUID userId = UUID.randomUUID();
        var token = tokenService.issue(userId);
        var decoded = jwtDecoder.decode(token.token());
        assertThat(decoded.getSubject()).isEqualTo(userId.toString());
        assertThat(decoded.getAudience()).containsExactly("p2p-chat-app");
        assertThat(decoded.getExpiresAt()).isAfter(decoded.getIssuedAt());
    }

    @Test
    void openApiDocumentIsPubliclyAvailable() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "/v3/api-docs")).GET().build();
        HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("P2P Modular Messenger API", "/api/v1/invites", "bearerAuth");
    }
}
