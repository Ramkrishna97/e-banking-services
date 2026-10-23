CREATE DATABASE IF NOT EXISTS account_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE account_db;

CREATE TABLE accounts (
    id BINARY(16) PRIMARY KEY,
    account_number CHAR(16) NOT NULL UNIQUE,
    customer_id BINARY(16) NOT NULL COMMENT 'Foreign identity only; no cross-service FK',
    account_type ENUM('SAVINGS','CURRENT','FIXED_DEPOSIT','RECURRING_DEPOSIT') NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    status ENUM('ACTIVE','FROZEN','DORMANT','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    available_balance DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    ledger_balance DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    minimum_balance DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    opened_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    closed_at TIMESTAMP(6) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    CHECK (available_balance >= 0),
    CHECK (ledger_balance >= 0),
    INDEX idx_account_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE account_holds (
    id BINARY(16) PRIMARY KEY,
    account_id BINARY(16) NOT NULL,
    transfer_reference VARCHAR(64) NOT NULL UNIQUE,
    amount DECIMAL(19,4) NOT NULL,
    status ENUM('ACTIVE','RELEASED','CAPTURED','EXPIRED') NOT NULL DEFAULT 'ACTIVE',
    expires_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CHECK (amount > 0),
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    INDEX idx_hold_account_status (account_id, status)
) ENGINE=InnoDB;

CREATE TABLE beneficiaries (
    id BINARY(16) PRIMARY KEY,
    customer_id BINARY(16) NOT NULL,
    beneficiary_name VARCHAR(160) NOT NULL,
    account_number VARCHAR(34) NOT NULL,
    ifsc_code CHAR(11) NULL,
    payment_rail ENUM('IMPS','NEFT','RTGS','UPI') NOT NULL,
    status ENUM('PENDING','ACTIVE','BLOCKED') NOT NULL DEFAULT 'PENDING',
    cooling_period_ends_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_beneficiary (customer_id, account_number, payment_rail),
    INDEX idx_beneficiary_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE account_statement_projection (
    id BINARY(16) PRIMARY KEY,
    account_id BINARY(16) NOT NULL,
    ledger_entry_reference VARCHAR(64) NOT NULL UNIQUE,
    booking_date DATE NOT NULL,
    value_date DATE NOT NULL,
    narration VARCHAR(255) NOT NULL,
    debit_amount DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    credit_amount DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    running_balance DECIMAL(19,4) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CHECK ((debit_amount = 0 AND credit_amount > 0) OR (credit_amount = 0 AND debit_amount > 0)),
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    INDEX idx_statement_account_date (account_id, booking_date DESC, created_at DESC)
) ENGINE=InnoDB;

CREATE TABLE outbox_events (
    id BINARY(16) PRIMARY KEY, aggregate_type VARCHAR(80) NOT NULL, aggregate_id BINARY(16) NOT NULL,
    event_type VARCHAR(120) NOT NULL, payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), published_at TIMESTAMP(6) NULL,
    INDEX idx_outbox_unpublished (published_at, occurred_at)
) ENGINE=InnoDB;
