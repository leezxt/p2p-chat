package com.p2pchat;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import com.p2pchat.modules.devices.presentation.RegistrationController;

@ActiveProfiles("prod")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=jdbc:h2:mem:p2p_chat_prod;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.flyway.locations=classpath:db/migration",
        "app.security.jwt.secret=dGVzdC1qd3Qtc2VjcmV0LW11c3QtYmUtYXQtbGVhc3QtMzItYnl0ZXMtbG9uZw=="
})
class ProductionProfileSecurityIntegrationTest {
    @Value("${local.server.port}") int port;
    @Autowired ApplicationContext context;

    @Test
    void productionDisablesLocalRegistrationAndApiDocumentation() throws Exception {
        assertThat(context.getBeansOfType(RegistrationController.class)).isEmpty();
        HttpClient client = HttpClient.newHttpClient();
        assertThat(get(client, "/v3/api-docs").statusCode()).isEqualTo(404);
        assertThat(get(client, "/swagger-ui.html").statusCode()).isEqualTo(404);
        assertThat(get(client, "/api/v1/registration").statusCode()).isEqualTo(404);
    }

    private HttpResponse<String> get(HttpClient client, String path) throws Exception {
        return client.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).GET().build(),
                HttpResponse.BodyHandlers.ofString());
    }
}
