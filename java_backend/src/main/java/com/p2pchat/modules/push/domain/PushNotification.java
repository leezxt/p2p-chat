package com.p2pchat.modules.push.domain;

import java.util.Map;

public record PushNotification(int schemaVersion, String type) {
    public static final String MAILBOX_AVAILABLE = "MAILBOX_AVAILABLE";

    public static PushNotification mailboxAvailable() {
        return new PushNotification(1, MAILBOX_AVAILABLE);
    }

    public Map<String, String> data() {
        return Map.of("schemaVersion", Integer.toString(schemaVersion), "type", type);
    }
}
