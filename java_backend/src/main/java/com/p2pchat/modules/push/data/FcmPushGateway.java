package com.p2pchat.modules.push.data;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import com.google.auth.oauth2.GoogleCredentials;
import com.p2pchat.modules.push.domain.PushDeliveryResult;
import com.p2pchat.modules.push.domain.PushGateway;
import com.p2pchat.modules.push.domain.PushNotification;
import com.p2pchat.modules.push.domain.PushProvider;
import tools.jackson.databind.json.JsonMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.push.fcm.enabled", havingValue = "true")
public class FcmPushGateway implements PushGateway {
    private static final String MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
    private final HttpClient http;
    private final GoogleCredentials credentials;
    private final JsonMapper json;
    private final URI endpoint;

    @Autowired
    public FcmPushGateway(JsonMapper json, @Value("${app.push.fcm.project-id}") String projectId)
            throws IOException {
        this(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(),
                GoogleCredentials.getApplicationDefault().createScoped(MESSAGING_SCOPE), json,
                endpoint(projectId));
    }

    FcmPushGateway(HttpClient http, GoogleCredentials credentials, JsonMapper json, URI endpoint) {
        this.http = http;
        this.credentials = credentials;
        this.json = json;
        this.endpoint = endpoint;
    }

    @Override
    public PushProvider provider() {
        return PushProvider.FCM;
    }

    @Override
    public PushDeliveryResult send(String token, PushNotification notification) {
        try {
            credentials.refreshIfExpired();
            var accessToken = credentials.getAccessToken();
            if (accessToken == null) accessToken = credentials.refreshAccessToken();
            String body = json.writeValueAsString(Map.of("message",
                    Map.of("token", token, "data", notification.data())));
            var request = HttpRequest.newBuilder(endpoint)
                    .timeout(Duration.ofSeconds(15))
                    .header("Authorization", "Bearer " + accessToken.getTokenValue())
                    .header("Content-Type", "application/json; charset=utf-8")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            var response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 200 && response.statusCode() < 300)
                return PushDeliveryResult.delivered();
            return classify(response.statusCode(), response.body(), json);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return PushDeliveryResult.retryable("FCM_INTERRUPTED");
        } catch (IOException | RuntimeException exception) {
            return PushDeliveryResult.retryable("FCM_IO_ERROR");
        }
    }

    static PushDeliveryResult classify(int httpStatus, String body, JsonMapper json) {
        String status = "";
        try {
            status = json.readTree(body).path("error").path("status").asText("");
        } catch (RuntimeException ignored) {
            // Fall back to the HTTP status without retaining provider response text.
        }
        String normalized = status.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9_]", "_");
        String errorCode = normalized.isBlank() ? "FCM_HTTP_" + httpStatus : "FCM_" + normalized;
        if ("UNREGISTERED".equals(normalized) || "NOT_FOUND".equals(normalized))
            return PushDeliveryResult.invalidToken(errorCode);
        if (httpStatus == 429 || httpStatus >= 500 ||
                "UNAVAILABLE".equals(normalized) || "INTERNAL".equals(normalized) ||
                "RESOURCE_EXHAUSTED".equals(normalized) || "QUOTA_EXCEEDED".equals(normalized))
            return PushDeliveryResult.retryable(errorCode);
        return PushDeliveryResult.permanent(errorCode);
    }

    private static URI endpoint(String projectId) {
        if (projectId == null || !projectId.matches("[a-z][a-z0-9-]{4,29}"))
            throw new IllegalStateException("Invalid Firebase project id");
        return URI.create("https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send");
    }
}
