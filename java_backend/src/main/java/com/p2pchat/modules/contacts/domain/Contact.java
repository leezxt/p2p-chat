package com.p2pchat.modules.contacts.domain;

import java.time.Instant;
import java.util.UUID;
import com.p2pchat.modules.users.domain.User;
import jakarta.persistence.*;

@Entity
@Table(name = "contacts", uniqueConstraints = @UniqueConstraint(
        name = "uq_contacts_owner_contact", columnNames = {"owner_user_id", "contact_user_id"}))
public class Contact {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_user_id", nullable = false) private User owner;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contact_user_id", nullable = false) private User contactUser;
    @Column(length = 100) private String alias;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected Contact() {}

    public Contact(UUID id, User owner, User contactUser, String alias, Instant now) {
        if (owner.getId().equals(contactUser.getId())) {
            throw new IllegalArgumentException("A user cannot be their own contact");
        }
        this.id = id; this.owner = owner; this.contactUser = contactUser;
        this.alias = alias; this.createdAt = now; this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public User getOwner() { return owner; }
    public User getContactUser() { return contactUser; }
    public String getAlias() { return alias; }
}
