package com.p2pchat.modules.mailbox.data;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import com.p2pchat.modules.mailbox.domain.MailboxMessage;
import com.p2pchat.modules.mailbox.domain.MailboxState;

public interface MailboxMessageRepository extends JpaRepository<MailboxMessage, UUID> {
    Optional<MailboxMessage> findBySenderDeviceIdAndMessageId(UUID senderDeviceId, String messageId);
    List<MailboxMessage> findByRecipientDeviceIdAndStateOrderByStoredAtAscIdAsc(UUID deviceId, MailboxState state);
    List<MailboxMessage> findBySenderDeviceIdOrderByUpdatedAtAscIdAsc(UUID deviceId);
    List<MailboxMessage> findByStateAndExpiresAtBefore(MailboxState state, Instant now);
    long countByRecipientDeviceIdAndState(UUID deviceId, MailboxState state);
    @Query("select coalesce(sum(m.ciphertextBytes), 0) from MailboxMessage m where m.recipientDevice.id = :deviceId and m.state = :state")
    long pendingBytes(UUID deviceId, MailboxState state);
}
