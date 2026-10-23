package com.ebanking.transfer;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
interface TransferRepository extends JpaRepository<Transfer, UUID> { Optional<Transfer> findByRequesterIdAndIdempotencyKey(UUID requesterId, String idempotencyKey); }
