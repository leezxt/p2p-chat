package com.p2pchat.modules.signaling.domain;

public enum SignalingType {
    AUTH, AUTHENTICATED, OFFER, ANSWER, ICE_CANDIDATE, CLOSE, ERROR;

    public boolean isRelayable() {
        return this == OFFER || this == ANSWER || this == ICE_CANDIDATE || this == CLOSE;
    }
}
