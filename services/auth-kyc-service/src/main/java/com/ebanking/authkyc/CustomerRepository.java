package com.ebanking.authkyc;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
interface CustomerRepository extends JpaRepository<Customer, UUID> { Optional<Customer> findByEmail(String email); }
