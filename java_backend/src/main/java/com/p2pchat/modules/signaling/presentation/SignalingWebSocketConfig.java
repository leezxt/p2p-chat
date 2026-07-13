package com.p2pchat.modules.signaling.presentation;

import java.util.Arrays;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.web.socket.config.annotation.*;

@Configuration
@EnableWebSocket
public class SignalingWebSocketConfig implements WebSocketConfigurer {
    private final SignalingWebSocketHandler handler;
    private final String[] allowedOrigins;

    public SignalingWebSocketConfig(SignalingWebSocketHandler handler, Environment environment) {
        this.handler = handler;
        this.allowedOrigins = Arrays.stream(environment.getProperty(
                        "app.security.websocket.allowed-origins", String[].class, new String[0]))
                .map(String::trim).filter(origin -> !origin.isEmpty()).distinct().toArray(String[]::new);
        if (environment.acceptsProfiles(Profiles.of("prod")) && Arrays.asList(allowedOrigins).contains("*")) {
            throw new IllegalStateException("Wildcard WebSocket origins are forbidden in production");
        }
    }

    @Override public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, "/ws/signaling").setAllowedOrigins(allowedOrigins);
    }
}
