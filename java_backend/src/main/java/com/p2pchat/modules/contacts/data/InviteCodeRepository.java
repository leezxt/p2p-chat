package com.p2pchat.modules.contacts.data;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import com.p2pchat.modules.contacts.domain.InviteCode;
import jakarta.persistence.LockModeType;

public interface InviteCodeRepository extends JpaRepository<InviteCode, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from InviteCode i where i.codeHash = :codeHash")
    Optional<InviteCode> findByCodeHashForUpdate(@Param("codeHash") String codeHash);
}
