package com.ebanking.authkyc;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "customers")
@SecondaryTable(name = "credentials", pkJoinColumns = @PrimaryKeyJoinColumn(name = "customer_id"))
class Customer {
    @Id UUID id;
    @Column(name = "customer_reference", nullable = false, unique = true, length = 24) String customerReference;
    @Column(nullable = false, unique = true) String email;
    @Column(name = "mobile_number", nullable = false, unique = true) String mobileNumber;
    @Column(name = "legal_name", nullable = false) String legalName;
    @Column(name = "date_of_birth", nullable = false) LocalDate dateOfBirth;
    @Enumerated(EnumType.STRING) @Column(name = "customer_type", nullable = false) CustomerType customerType;
    @Column(name = "password_hash", table = "credentials", nullable = false) String passwordHash;
    @Transient String role = "ROLE_RETAIL_CUSTOMER";
    @Transient boolean mfaEnabled;
    enum CustomerType { RETAIL, CORPORATE }
}
