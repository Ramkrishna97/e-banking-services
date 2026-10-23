package com.ebanking.card;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
interface CardRepository extends JpaRepository<Card, UUID> { Optional<Card> findByIdAndCustomerId(UUID id, UUID customerId); }
