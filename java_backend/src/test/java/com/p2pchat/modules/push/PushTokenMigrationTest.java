package com.p2pchat.modules.push;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.DriverManager;
import java.time.Instant;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

class PushTokenMigrationTest {
    @Test
    void v7InvalidatesLegacyPlaintextTokens() throws Exception {
        String url = "jdbc:h2:mem:push_token_migration;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1";
        UUID userId = UUID.randomUUID();
        UUID deviceId = UUID.randomUUID();
        UUID tokenId = UUID.randomUUID();
        Instant now = Instant.now();
        try (var connection = DriverManager.getConnection(url, "sa", "")) {
            var dataSource = new SingleConnectionDataSource(connection, true);
            Flyway.configure().dataSource(dataSource).locations("classpath:db/migration").target("6").load().migrate();
            try (var statement = connection.prepareStatement(
                    "INSERT INTO users (id, username, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")) {
                statement.setObject(1, userId); statement.setString(2, "migration-user");
                statement.setString(3, "Migration"); statement.setObject(4, now);
                statement.setObject(5, now); statement.executeUpdate();
            }
            try (var statement = connection.prepareStatement(
                    "INSERT INTO devices (id, user_id, name, public_key, public_key_fingerprint, created_at, updated_at) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?)")) {
                statement.setObject(1, deviceId); statement.setObject(2, userId); statement.setString(3, "Phone");
                statement.setString(4, "pk"); statement.setString(5, "fp");
                statement.setObject(6, now); statement.setObject(7, now); statement.executeUpdate();
            }
            try (var statement = connection.prepareStatement(
                    "INSERT INTO device_push_tokens "
                            + "(id, device_id, provider, token, token_hash, created_at, updated_at) "
                            + "VALUES (?, ?, 'FCM', 'legacy-plaintext', ?, ?, ?)")) {
                statement.setObject(1, tokenId); statement.setObject(2, deviceId);
                statement.setString(3, "a".repeat(64)); statement.setObject(4, now);
                statement.setObject(5, now); statement.executeUpdate();
            }
            Flyway.configure().dataSource(dataSource).locations("classpath:db/migration").load().migrate();

            try (var statement = connection.prepareStatement(
                        "SELECT token_ciphertext, revoked_at FROM device_push_tokens WHERE id = ?")) {
                statement.setObject(1, tokenId);
                try (var result = statement.executeQuery()) {
                    assertThat(result.next()).isTrue();
                    assertThat(result.getString("token_ciphertext")).isNull();
                    assertThat(result.getObject("revoked_at")).isNotNull();
                }
            }
        }
    }
}
