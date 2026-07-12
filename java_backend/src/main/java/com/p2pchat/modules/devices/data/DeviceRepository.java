package com.p2pchat.modules.devices.data;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.p2pchat.modules.devices.domain.Device;

public interface DeviceRepository extends JpaRepository<Device, UUID> {
    List<Device> findByUserIdAndRevokedAtIsNull(UUID userId);
    Optional<Device> findByPublicKeyFingerprint(String fingerprint);
    boolean existsByIdAndUserIdAndRevokedAtIsNull(UUID id, UUID userId);
    Optional<Device> findFirstByUserIdAndRevokedAtIsNullOrderByCreatedAtAsc(UUID userId);
}
