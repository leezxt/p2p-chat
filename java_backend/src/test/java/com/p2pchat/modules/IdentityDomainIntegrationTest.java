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
import com.p2pchat.modules.contacts.domain.Contact;
import com.p2pchat.modules.devices.data.DeviceRepository;
import com.p2pchat.modules.devices.domain.Device;
import com.p2pchat.modules.users.data.UserRepository;
import com.p2pchat.modules.users.domain.User;

@ActiveProfiles("test")
@SpringBootTest
@Transactional
class IdentityDomainIntegrationTest {
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired ContactRepository contacts;

    @Test
    void persistsUsersDeviceAndDirectedContact() {
        Instant now = Instant.now();
        User alice = users.save(new User(UUID.randomUUID(), "alice", "Alice", now));
        User bob = users.save(new User(UUID.randomUUID(), "bob", "Bob", now));
        Device phone = devices.save(new Device(UUID.randomUUID(), alice, "Phone", "public-key", "sha256:a1", now));
        contacts.save(new Contact(UUID.randomUUID(), alice, bob, "Bobby", now));

        assertThat(devices.findByUserIdAndRevokedAtIsNull(alice.getId())).extracting(Device::getId).containsExactly(phone.getId());
        assertThat(contacts.findByOwnerIdAndContactUserId(alice.getId(), bob.getId())).isPresent();
        assertThat(contacts.findByOwnerId(bob.getId())).isEmpty();
    }

    @Test
    void rejectsSelfContactInDomain() {
        User alice = new User(UUID.randomUUID(), null, "Alice", Instant.now());
        assertThatThrownBy(() -> new Contact(UUID.randomUUID(), alice, alice, null, Instant.now()))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
