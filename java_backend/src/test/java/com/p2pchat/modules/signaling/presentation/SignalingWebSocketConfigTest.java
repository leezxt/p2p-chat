package com.p2pchat.modules.signaling.presentation;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistration;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

class SignalingWebSocketConfigTest {
    private final SignalingWebSocketHandler handler = mock(SignalingWebSocketHandler.class);

    @Test
    void productionDefaultsToEmptyOriginAllowlist() {
        var environment = new MockEnvironment();
        environment.setActiveProfiles("prod");

        var registration = register(new SignalingWebSocketConfig(handler, environment));

        verify(registration).setAllowedOrigins();
    }

    @Test
    void productionUsesOnlyConfiguredOrigins() {
        var environment = new MockEnvironment()
                .withProperty("app.security.websocket.allowed-origins",
                        "https://app.example.test, https://admin.example.test");
        environment.setActiveProfiles("prod");

        var registration = register(new SignalingWebSocketConfig(handler, environment));

        verify(registration).setAllowedOrigins("https://app.example.test", "https://admin.example.test");
    }

    @Test
    void productionRejectsWildcardOrigin() {
        var environment = new MockEnvironment()
                .withProperty("app.security.websocket.allowed-origins", "*");
        environment.setActiveProfiles("prod");

        assertThatThrownBy(() -> new SignalingWebSocketConfig(handler, environment))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Wildcard WebSocket origins are forbidden in production");
    }

    private WebSocketHandlerRegistration register(SignalingWebSocketConfig config) {
        var registry = mock(WebSocketHandlerRegistry.class);
        var registration = mock(WebSocketHandlerRegistration.class);
        when(registry.addHandler(handler, "/ws/signaling")).thenReturn(registration);
        config.registerWebSocketHandlers(registry);
        return registration;
    }
}
