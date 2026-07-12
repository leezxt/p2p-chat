package com.p2pchat.modules.push.domain;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import com.p2pchat.modules.mailbox.domain.MailboxMessage;
import com.p2pchat.modules.push.data.NotificationOutboxRepository;

@Service
public class NotificationOutboxService {
    private final NotificationOutboxRepository outbox;

    public NotificationOutboxService(NotificationOutboxRepository outbox) { this.outbox = outbox; }

    public void enqueue(MailboxMessage message) {
        if (outbox.findByMailboxMessageIdAndEventType(message.getId(), "MAILBOX_AVAILABLE").isPresent()) return;
        outbox.save(new NotificationOutbox(UUID.randomUUID(), message.getId(),
                message.getRecipientDevice(), Instant.now()));
    }
}
