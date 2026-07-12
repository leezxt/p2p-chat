package com.p2pchat.modules;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.contacts.domain.InviteCodeException;
import com.p2pchat.modules.contacts.domain.InviteCodeService;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;

@ActiveProfiles("test")
@SpringBootTest
@Transactional
class InviteCodeIntegrationTest {
    @Autowired UserRepository users;
    @Autowired ContactRepository contacts;
    @Autowired InviteCodeService service;
    @Autowired DeviceRepository devices;

    @Test
    void inviteCanBeRedeemedOnlyOnceAndCreatesBidirectionalContacts() {
        User alice = users.save(new User(UUID.randomUUID(), "invite-alice", "Alice", Instant.now()));
        User bob = users.save(new User(UUID.randomUUID(), "invite-bob", "Bob", Instant.now()));
        User carol = users.save(new User(UUID.randomUUID(), "invite-carol", "Carol", Instant.now()));
        devices.save(new Device(UUID.randomUUID(), alice, "Phone", "pk", "fp-" + UUID.randomUUID(), Instant.now()));
        var invite = service.create(alice.getId());

        service.redeem(invite.code(), bob.getId());

        assertThat(contacts.findByOwnerIdAndContactUserId(alice.getId(), bob.getId())).isPresent();
        assertThat(contacts.findByOwnerIdAndContactUserId(bob.getId(), alice.getId())).isPresent();
        assertThatThrownBy(() -> service.redeem(invite.code(), carol.getId()))
                .isInstanceOf(InviteCodeException.class).hasMessage("INVITE_ALREADY_REDEEMED");
    }

    @Test
    void invalidAndSelfRedeemedInvitesAreRejected() {
        User alice = users.save(new User(UUID.randomUUID(), "self-alice", "Alice", Instant.now()));
        assertThatThrownBy(() -> service.redeem("not-a-real-code", alice.getId()))
                .isInstanceOf(InviteCodeException.class).hasMessage("INVITE_NOT_FOUND");
        var invite = service.create(alice.getId());
        assertThatThrownBy(() -> service.redeem(invite.code(), alice.getId()))
                .isInstanceOf(InviteCodeException.class).hasMessage("SELF_REDEMPTION_NOT_ALLOWED");
    }
}
