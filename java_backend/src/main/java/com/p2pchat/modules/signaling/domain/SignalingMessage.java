package com.p2pchat.modules.signaling.domain;

import java.util.Map;

public record SignalingMessage(int schemaVersion, String type, String sessionId,
        String senderDeviceId, String targetDeviceId, Map<String, Object> payload) {}
