package com.p2pchat.modules.signaling.presentation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import com.p2pchat.modules.contacts.data.ContactRepository;
import com.p2pchat.modules.devices.data.DeviceRepository;
import tools.jackson.databind.json.JsonMapper;

class SignalingWebSocketHandlerTest {
    @Test
    void serializesConcurrentWritesToSameSession() throws Exception {
        SignalingWebSocketHandler handler = new SignalingWebSocketHandler(
                JsonMapper.builder().build(),
                mock(JwtDecoder.class),
                mock(DeviceRepository.class),
                mock(ContactRepository.class));
        WebSocketSession session = mock(WebSocketSession.class);
        CountDownLatch firstWriteEntered = new CountDownLatch(1);
        CountDownLatch releaseFirstWrite = new CountDownLatch(1);
        CountDownLatch secondTaskStarted = new CountDownLatch(1);
        CountDownLatch secondWriteEntered = new CountDownLatch(1);
        AtomicInteger writes = new AtomicInteger();

        doAnswer(invocation -> {
            int write = writes.incrementAndGet();
            if (write == 1) {
                firstWriteEntered.countDown();
                assertThat(releaseFirstWrite.await(2, TimeUnit.SECONDS)).isTrue();
            } else {
                secondWriteEntered.countDown();
            }
            return null;
        }).when(session).sendMessage(org.mockito.ArgumentMatchers.any(TextMessage.class));

        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> {
                handler.send(session, new TextMessage("first"));
                return null;
            });
            assertThat(firstWriteEntered.await(2, TimeUnit.SECONDS)).isTrue();
            var second = executor.submit(() -> {
                secondTaskStarted.countDown();
                handler.send(session, new TextMessage("second"));
                return null;
            });
            assertThat(secondTaskStarted.await(2, TimeUnit.SECONDS)).isTrue();
            assertThat(secondWriteEntered.await(200, TimeUnit.MILLISECONDS)).isFalse();

            releaseFirstWrite.countDown();
            first.get(2, TimeUnit.SECONDS);
            second.get(2, TimeUnit.SECONDS);
        }

        assertThat(writes).hasValue(2);
    }
}
