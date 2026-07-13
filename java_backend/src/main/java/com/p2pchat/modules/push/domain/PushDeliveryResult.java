package com.p2pchat.modules.push.domain;

public record PushDeliveryResult(Status status, String errorCode) {
    public PushDeliveryResult {
        if (status == null) throw new IllegalArgumentException("Push delivery status is required");
        if (errorCode != null && !errorCode.matches("[A-Z0-9_]{1,64}"))
            throw new IllegalArgumentException("Invalid push delivery error code");
    }

    public static PushDeliveryResult delivered() {
        return new PushDeliveryResult(Status.DELIVERED, null);
    }

    public static PushDeliveryResult invalidToken(String errorCode) {
        return new PushDeliveryResult(Status.INVALID_TOKEN, errorCode);
    }

    public static PushDeliveryResult retryable(String errorCode) {
        return new PushDeliveryResult(Status.RETRYABLE_FAILURE, errorCode);
    }

    public static PushDeliveryResult permanent(String errorCode) {
        return new PushDeliveryResult(Status.PERMANENT_FAILURE, errorCode);
    }

    public enum Status {
        DELIVERED,
        INVALID_TOKEN,
        RETRYABLE_FAILURE,
        PERMANENT_FAILURE
    }
}
