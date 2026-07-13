package com.p2pchat.modules.push.data;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.concurrent.atomic.AtomicReference;
import com.google.auth.oauth2.AccessToken;
import com.google.auth.oauth2.GoogleCredentials;
import com.p2pchat.modules.push.domain.PushDeliveryResult;
import com.p2pchat.modules.push.domain.PushNotification;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class FcmPushGatewayTest {
    private final JsonMapper json = JsonMapper.builder().build();

    @Test
    void sendsAnAuthorizedDataOnlyHttpV1Request() throws Exception {
        var requestBody = new AtomicReference<String>();
        var authorization = new AtomicReference<String>();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/projects/test-project/messages:send", exchange -> {
            authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] response = "{\"name\":\"projects/test/messages/1\"}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        server.start();
        try {
            var credentials = GoogleCredentials.create(new AccessToken(
                    "test-access-token", Date.from(Instant.now().plusSeconds(3600))));
            var endpoint = URI.create("http://127.0.0.1:" + server.getAddress().getPort()
                    + "/v1/projects/test-project/messages:send");
            var gateway = new FcmPushGateway(HttpClient.newHttpClient(), credentials, json, endpoint);

            assertThat(gateway.send("secret-provider-token", PushNotification.mailboxAvailable()).status())
                    .isEqualTo(PushDeliveryResult.Status.DELIVERED);
            assertThat(authorization).hasValue("Bearer test-access-token");
            var root = json.readTree(requestBody.get());
            assertThat(root.path("message").path("token").asText()).isEqualTo("secret-provider-token");
            assertThat(root.path("message").path("data").properties())
                    .extracting(java.util.Map.Entry::getKey)
                    .containsExactlyInAnyOrder("schemaVersion", "type");
            assertThat(root.path("message").has("notification")).isFalse();
            assertThat(requestBody.get()).doesNotContain("sender", "conversation", "ciphertext", "plaintext");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void classifiesInvalidTransientAndPermanentHttpV1Errors() {
        assertThat(FcmPushGateway.classify(404, error("NOT_FOUND"), json).status())
                .isEqualTo(PushDeliveryResult.Status.INVALID_TOKEN);
        assertThat(FcmPushGateway.classify(503, error("UNAVAILABLE"), json).status())
                .isEqualTo(PushDeliveryResult.Status.RETRYABLE_FAILURE);
        assertThat(FcmPushGateway.classify(429, error("RESOURCE_EXHAUSTED"), json).status())
                .isEqualTo(PushDeliveryResult.Status.RETRYABLE_FAILURE);
        assertThat(FcmPushGateway.classify(400, error("INVALID_ARGUMENT"), json).status())
                .isEqualTo(PushDeliveryResult.Status.PERMANENT_FAILURE);
        assertThat(FcmPushGateway.classify(500, "not-json", json).errorCode())
                .isEqualTo("FCM_HTTP_500");
    }

    private static String error(String status) {
        return "{\"error\":{\"status\":\"" + status + "\"}}";
    }
}
