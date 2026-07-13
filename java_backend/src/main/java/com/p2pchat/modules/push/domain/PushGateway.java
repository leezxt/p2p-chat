package com.p2pchat.modules.push.domain;

public interface PushGateway {
    PushProvider provider();
    PushDeliveryResult send(String token, PushNotification notification);
}
