package com.p2pchat.modules.signaling.presentation;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.*;

@Configuration
@EnableWebSocket
public class SignalingWebSocketConfig implements WebSocketConfigurer {
    private final SignalingWebSocketHandler handler;
    public SignalingWebSocketConfig(SignalingWebSocketHandler handler) { this.handler = handler; }
    @Override public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, "/ws/signaling").setAllowedOrigins("*");
    }
}
