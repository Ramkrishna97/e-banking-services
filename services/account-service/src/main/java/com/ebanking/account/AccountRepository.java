package com.ebanking.account;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

interface AccountRepository extends JpaRepository<Account, UUID> {
    List<Account> findByCustomerId(UUID customerId);
    Optional<Account> findByIdAndCustomerId(UUID id, UUID customerId);
}
