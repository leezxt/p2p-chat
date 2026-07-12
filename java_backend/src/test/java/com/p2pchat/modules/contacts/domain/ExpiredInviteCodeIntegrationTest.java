package com.p2pchat.modules.contacts.domain;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import com.p2pchat.modules.contacts.data.InviteCodeRepository;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;

@ActiveProfiles("test")
@SpringBootTest
@Transactional
class ExpiredInviteCodeIntegrationTest {
    @Autowired UserRepository users;
    @Autowired InviteCodeRepository invites;
    @Autowired InviteCodeService service;

    @Test
    void expiredInviteIsRejected() throws Exception {
        Instant now = Instant.now();
        User alice = users.save(new User(UUID.randomUUID(), "expired-alice", "Alice", now));
        User bob = users.save(new User(UUID.randomUUID(), "expired-bob", "Bob", now));
        String rawCode = "expired-code";
        String codeHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(rawCode.getBytes(StandardCharsets.UTF_8)));
        invites.save(new InviteCode(UUID.randomUUID(), alice, codeHash, now.minusSeconds(1), now.minusSeconds(60)));

        assertThatThrownBy(() -> service.redeem(rawCode, bob.getId()))
                .isInstanceOf(InviteCodeException.class)
                .hasMessage("INVITE_EXPIRED");
    }
}
