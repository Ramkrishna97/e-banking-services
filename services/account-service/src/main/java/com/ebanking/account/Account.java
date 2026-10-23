package com.ebanking.account;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "accounts")
class Account {
    @Id UUID id;
    @Column(unique = true, nullable = false, columnDefinition = "char(16)") String accountNumber;
    @Column(nullable = false) UUID customerId;
    @Enumerated(EnumType.STRING) @Column(nullable = false) AccountType accountType;
    @Enumerated(EnumType.STRING) @Column(nullable = false) AccountStatus status = AccountStatus.ACTIVE;
    @Column(nullable = false, precision = 19, scale = 4) BigDecimal availableBalance = BigDecimal.ZERO;
    @Column(nullable = false, precision = 19, scale = 4) BigDecimal minimumBalance = BigDecimal.ZERO;
    @Version Long version;
    @Column(nullable = false) Instant openedAt = Instant.now();
    enum AccountType { SAVINGS, CURRENT, FIXED_DEPOSIT, RECURRING_DEPOSIT }
    enum AccountStatus { ACTIVE, FROZEN, DORMANT, CLOSED }
}
