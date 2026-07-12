package com.p2pchat.modules.contacts.presentation;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import com.p2pchat.modules.contacts.domain.InviteCodeException;
import com.p2pchat.modules.contacts.domain.InviteCodeService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/v1/invites")
public class InviteCodeController {
    private final InviteCodeService service;
    public InviteCodeController(InviteCodeService service) { this.service = service; }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CreateInviteResponse create(@AuthenticationPrincipal Jwt jwt) {
        var invite = service.create(UUID.fromString(jwt.getSubject()));
        return new CreateInviteResponse(invite.code(), invite.expiresAt());
    }

    @PostMapping("/redeem")
    public RedeemedContactResponse redeem(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RedeemInviteRequest request) {
        var contact = service.redeem(request.code(), UUID.fromString(jwt.getSubject()));
        return new RedeemedContactResponse(contact.userId(), contact.displayName(), contact.deviceId(),
                contact.publicKey(), contact.publicKeyFingerprint());
    }

    @GetMapping("/contacts")
    public List<RedeemedContactResponse> contacts(@AuthenticationPrincipal Jwt jwt) {
        return service.listContacts(UUID.fromString(jwt.getSubject())).stream()
                .map(contact -> new RedeemedContactResponse(contact.userId(), contact.displayName(), contact.deviceId(),
                        contact.publicKey(), contact.publicKeyFingerprint()))
                .toList();
    }

    @ExceptionHandler(InviteCodeException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleInviteError(InviteCodeException error) { return new ErrorResponse(error.getMessage()); }

    public record CreateInviteResponse(String code, Instant expiresAt) {}
    public record RedeemInviteRequest(@NotBlank @Size(max = 128) String code) {}
    public record RedeemedContactResponse(UUID userId, String displayName, UUID deviceId,
            String publicKey, String publicKeyFingerprint) {}
    public record ErrorResponse(String code) {}
}
