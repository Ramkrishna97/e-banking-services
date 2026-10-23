CREATE DATABASE IF NOT EXISTS transaction_ledger_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE transaction_ledger_db;

CREATE TABLE payment_transfers (
    id BINARY(16) PRIMARY KEY,
    transfer_reference VARCHAR(64) NOT NULL UNIQUE,
    idempotency_key VARCHAR(128) NOT NULL,
    requester_id BINARY(16) NOT NULL,
    source_account_id BINARY(16) NOT NULL,
    destination_account_reference VARCHAR(64) NOT NULL,
    payment_rail ENUM('IMPS','NEFT','RTGS','UPI') NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    fee_amount DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    tds_amount DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    status ENUM('INITIATED','VALIDATED','POSTED','SETTLED','FAILED','REVERSED') NOT NULL,
    failure_code VARCHAR(80) NULL,
    response_payload JSON NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_idempotency_requester (requester_id, idempotency_key),
    CHECK (amount > 0), CHECK (fee_amount >= 0), CHECK (tds_amount >= 0),
    INDEX idx_transfer_source_created (source_account_id, created_at DESC)
) ENGINE=InnoDB;

CREATE TABLE ledger_accounts (
    id BINARY(16) PRIMARY KEY,
    account_code VARCHAR(48) NOT NULL UNIQUE,
    account_type ENUM('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE') NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE journal_entries (
    id BINARY(16) PRIMARY KEY,
    transfer_id BINARY(16) NULL,
    entry_reference VARCHAR(64) NOT NULL UNIQUE,
    status ENUM('PENDING','POSTED','REVERSED') NOT NULL DEFAULT 'PENDING',
    booking_date DATE NOT NULL,
    description VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    posted_at TIMESTAMP(6) NULL,
    FOREIGN KEY (transfer_id) REFERENCES payment_transfers(id),
    INDEX idx_journal_transfer (transfer_id)
) ENGINE=InnoDB;

CREATE TABLE journal_lines (
    id BINARY(16) PRIMARY KEY,
    journal_entry_id BINARY(16) NOT NULL,
    ledger_account_id BINARY(16) NOT NULL,
    line_type ENUM('DEBIT','CREDIT') NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id),
    FOREIGN KEY (ledger_account_id) REFERENCES ledger_accounts(id),
    CHECK (amount > 0),
    INDEX idx_line_journal (journal_entry_id)
) ENGINE=InnoDB;

CREATE TABLE saga_instances (
    id BINARY(16) PRIMARY KEY,
    transfer_id BINARY(16) NOT NULL UNIQUE,
    state ENUM('STARTED','ACCOUNT_VALIDATED','LEDGER_POSTED','NOTIFIED','COMPENSATING','COMPLETED','FAILED') NOT NULL,
    last_error VARCHAR(500) NULL,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    FOREIGN KEY (transfer_id) REFERENCES payment_transfers(id)
) ENGINE=InnoDB;

CREATE TABLE outbox_events (
    id BINARY(16) PRIMARY KEY, aggregate_type VARCHAR(80) NOT NULL, aggregate_id BINARY(16) NOT NULL,
    event_type VARCHAR(120) NOT NULL, payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), published_at TIMESTAMP(6) NULL,
    INDEX idx_outbox_unpublished (published_at, occurred_at)
) ENGINE=InnoDB;
