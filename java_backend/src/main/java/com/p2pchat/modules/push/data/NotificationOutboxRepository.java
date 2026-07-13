package com.p2pchat.modules.push.data;

import java.util.Optional;
import java.util.UUID;
import java.time.Instant;
import java.util.List;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import com.p2pchat.modules.push.domain.NotificationOutbox;

public interface NotificationOutboxRepository extends JpaRepository<NotificationOutbox, UUID> {
    Optional<NotificationOutbox> findByMailboxMessageIdAndEventType(UUID mailboxMessageId, String eventType);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT item FROM NotificationOutbox item
            WHERE (item.state = 'PENDING' AND item.nextAttemptAt <= :now)
               OR (item.state = 'PROCESSING' AND item.leaseUntil <= :now)
            ORDER BY item.createdAt ASC
            """)
    List<NotificationOutbox> findDispatchable(@Param("now") Instant now, Pageable pageable);
}
