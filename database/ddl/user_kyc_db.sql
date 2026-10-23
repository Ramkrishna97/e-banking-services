CREATE DATABASE IF NOT EXISTS user_kyc_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE user_kyc_db;

CREATE TABLE customers (
    id BINARY(16) PRIMARY KEY,
    customer_reference VARCHAR(24) NOT NULL UNIQUE,
    email VARCHAR(254) NOT NULL UNIQUE,
    mobile_number VARCHAR(20) NOT NULL UNIQUE,
    legal_name VARCHAR(160) NOT NULL,
    date_of_birth DATE NOT NULL,
    customer_type ENUM('RETAIL','CORPORATE') NOT NULL,
    status ENUM('PENDING_KYC','ACTIVE','SUSPENDED','CLOSED') NOT NULL DEFAULT 'PENDING_KYC',
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE credentials (
    customer_id BINARY(16) PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    password_changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    failed_attempts SMALLINT NOT NULL DEFAULT 0,
    locked_until TIMESTAMP(6) NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB;

CREATE TABLE roles (
    id BINARY(16) PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE
) ENGINE=InnoDB;
CREATE TABLE customer_roles (
    customer_id BINARY(16) NOT NULL,
    role_id BINARY(16) NOT NULL,
    granted_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (customer_id, role_id),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (role_id) REFERENCES roles(id)
) ENGINE=InnoDB;

CREATE TABLE kyc_cases (
    id BINARY(16) PRIMARY KEY,
    customer_id BINARY(16) NOT NULL,
    kyc_level ENUM('BASIC','FULL') NOT NULL,
    status ENUM('PENDING','VERIFIED','REJECTED','EXPIRED') NOT NULL DEFAULT 'PENDING',
    provider_reference VARCHAR(100) NULL UNIQUE,
    verified_at TIMESTAMP(6) NULL,
    expires_at TIMESTAMP(6) NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    INDEX idx_kyc_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE kyc_documents (
    id BINARY(16) PRIMARY KEY,
    kyc_case_id BINARY(16) NOT NULL,
    document_type ENUM('PAN','AADHAAR','PASSPORT','DRIVING_LICENSE','CORPORATE_REGISTRATION') NOT NULL,
    document_hash CHAR(64) NOT NULL,
    masked_identifier VARCHAR(80) NOT NULL,
    verification_status ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
    UNIQUE KEY uq_kyc_document (kyc_case_id, document_type),
    FOREIGN KEY (kyc_case_id) REFERENCES kyc_cases(id)
) ENGINE=InnoDB;

CREATE TABLE mfa_factors (
    id BINARY(16) PRIMARY KEY,
    customer_id BINARY(16) NOT NULL,
    factor_type ENUM('TOTP','SMS_OTP','EMAIL_OTP','BIOMETRIC') NOT NULL,
    secret_ciphertext VARBINARY(1024) NULL,
    verified_at TIMESTAMP(6) NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    INDEX idx_mfa_customer_enabled (customer_id, enabled)
) ENGINE=InnoDB;

CREATE TABLE refresh_tokens (
    id BINARY(16) PRIMARY KEY,
    customer_id BINARY(16) NOT NULL,
    token_hash CHAR(64) NOT NULL UNIQUE,
    family_id BINARY(16) NOT NULL,
    issued_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at TIMESTAMP(6) NOT NULL,
    revoked_at TIMESTAMP(6) NULL,
    replaced_by_token_id BINARY(16) NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    INDEX idx_refresh_family (family_id)
) ENGINE=InnoDB;

CREATE TABLE outbox_events (
    id BINARY(16) PRIMARY KEY,
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id BINARY(16) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    published_at TIMESTAMP(6) NULL,
    INDEX idx_outbox_unpublished (published_at, occurred_at)
) ENGINE=InnoDB;
