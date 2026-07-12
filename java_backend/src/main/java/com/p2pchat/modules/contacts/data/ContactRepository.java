package com.p2pchat.modules.contacts.data;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.p2pchat.modules.contacts.domain.Contact;

public interface ContactRepository extends JpaRepository<Contact, UUID> {
    List<Contact> findByOwnerId(UUID ownerId);
    Optional<Contact> findByOwnerIdAndContactUserId(UUID ownerId, UUID contactUserId);
}
