package com.p2pchat.modules.signaling.presentation;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.signaling.domain.SignalingType;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

@Component
public class SignalingWebSocketHandler extends TextWebSocketHandler {
    private final ObjectMapper json;
    private final JwtDecoder tokens;
    private final DeviceRepository devices;
    private final Map<String, WebSocketSession> sessionsByDevice = new ConcurrentHashMap<>();
    private final Map<String, String> deviceBySession = new ConcurrentHashMap<>();

    public SignalingWebSocketHandler(ObjectMapper json, JwtDecoder tokens, DeviceRepository devices) {
        this.json = json; this.tokens = tokens; this.devices = devices;
    }

    @Override protected void handleTextMessage(WebSocketSession session, TextMessage frame) throws Exception {
        JsonNode message;
        try { message = json.readTree(frame.getPayload()); }
        catch (RuntimeException e) { sendError(session, "INVALID_JSON"); return; }
        String typeValue = text(message, "type");
        SignalingType type;
        try { type = SignalingType.valueOf(typeValue); }
        catch (Exception e) { sendError(session, "INVALID_TYPE"); return; }
        if (!deviceBySession.containsKey(session.getId())) {
            if (type != SignalingType.AUTH) { sendError(session, "AUTH_REQUIRED"); return; }
            authenticate(session, message); return;
        }
        if (!type.isRelayable()) { sendError(session, "INVALID_TYPE"); return; }
        relay(session, message, type);
    }

    private void authenticate(WebSocketSession session, JsonNode message) throws IOException {
        try {
            UUID deviceId = UUID.fromString(text(message, "deviceId"));
            UUID userId = UUID.fromString(tokens.decode(text(message, "token")).getSubject());
            if (!devices.existsByIdAndUserIdAndRevokedAtIsNull(deviceId, userId)) {
                sendError(session, "DEVICE_NOT_OWNED"); return;
            }
            WebSocketSession previous = sessionsByDevice.put(deviceId.toString(), session);
            deviceBySession.put(session.getId(), deviceId.toString());
            if (previous != null && previous.isOpen()) previous.close(CloseStatus.POLICY_VIOLATION);
            ObjectNode response = json.createObjectNode();
            response.put("schemaVersion", 1).put("type", "AUTHENTICATED").put("deviceId", deviceId.toString());
            session.sendMessage(new TextMessage(json.writeValueAsString(response)));
        } catch (Exception e) { sendError(session, "AUTH_FAILED"); }
    }

    private void relay(WebSocketSession sender, JsonNode message, SignalingType type) throws IOException {
        String target = text(message, "targetDeviceId");
        String sessionId = text(message, "sessionId");
        if (target.isBlank() || sessionId.isBlank()) { sendError(sender, "INVALID_MESSAGE"); return; }
        WebSocketSession recipient = sessionsByDevice.get(target);
        if (recipient == null || !recipient.isOpen()) { sendError(sender, "TARGET_OFFLINE"); return; }
        ObjectNode outbound = json.createObjectNode();
        outbound.put("schemaVersion", 1).put("type", type.name()).put("sessionId", sessionId)
                .put("senderDeviceId", deviceBySession.get(sender.getId())).put("targetDeviceId", target);
        JsonNode payload = message.get("payload");
        if (payload != null) outbound.set("payload", payload);
        recipient.sendMessage(new TextMessage(json.writeValueAsString(outbound)));
    }

    private void sendError(WebSocketSession session, String code) throws IOException {
        ObjectNode error = json.createObjectNode();
        error.put("schemaVersion", 1).put("type", "ERROR").put("code", code);
        session.sendMessage(new TextMessage(json.writeValueAsString(error)));
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.get(field); return value == null ? "" : value.asText();
    }

    @Override public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String device = deviceBySession.remove(session.getId());
        if (device != null) sessionsByDevice.remove(device, session);
    }
}
