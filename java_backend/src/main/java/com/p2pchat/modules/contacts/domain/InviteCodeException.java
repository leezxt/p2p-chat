package com.p2pchat.modules.contacts.domain;

public class InviteCodeException extends RuntimeException {
    public InviteCodeException(String code) { super(code); }
}
