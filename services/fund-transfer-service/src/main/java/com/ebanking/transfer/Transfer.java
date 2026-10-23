package com.ebanking.transfer;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name = "payment_transfers", uniqueConstraints = @UniqueConstraint(name = "uq_idempotency_requester", columnNames = {"requesterId", "idempotencyKey"}))
class Transfer {
    @Id UUID id; @Column(nullable = false, unique = true) String transferReference;
    @Column(nullable = false) UUID requesterId; @Column(nullable = false) String idempotencyKey;
    @Column(nullable = false) UUID sourceAccountId; @Column(nullable = false) String destinationAccountReference;
    @Enumerated(EnumType.STRING) @Column(name = "payment_rail", nullable = false) Rail rail;
    @Column(nullable = false, precision = 19, scale = 4) BigDecimal amount;
    @Enumerated(EnumType.STRING) @Column(nullable = false) Status status;
    @Column(nullable = false) Instant createdAt = Instant.now();
    enum Rail { IMPS, NEFT, RTGS, UPI } enum Status { POSTED, FAILED, REVERSED }
}
