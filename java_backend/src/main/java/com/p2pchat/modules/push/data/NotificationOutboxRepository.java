package com.p2pchat.modules.push.data;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.p2pchat.modules.push.domain.NotificationOutbox;

public interface NotificationOutboxRepository extends JpaRepository<NotificationOutbox, UUID> {
    Optional<NotificationOutbox> findByMailboxMessageIdAndEventType(UUID mailboxMessageId, String eventType);
}
