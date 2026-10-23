CREATE DATABASE IF NOT EXISTS card_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE card_db;

CREATE TABLE cards (
    id BINARY(16) PRIMARY KEY,
    card_reference VARCHAR(40) NOT NULL UNIQUE,
    customer_id BINARY(16) NOT NULL,
    linked_account_id BINARY(16) NULL,
    card_type ENUM('DEBIT','CREDIT','VIRTUAL') NOT NULL,
    network ENUM('VISA','MASTERCARD','RUPAY') NOT NULL,
    pan_token VARCHAR(128) NOT NULL UNIQUE,
    last_four CHAR(4) NOT NULL,
    expiry_month TINYINT NOT NULL,
    expiry_year SMALLINT NOT NULL,
    status ENUM('PENDING_ACTIVATION','ACTIVE','BLOCKED','EXPIRED','CLOSED') NOT NULL DEFAULT 'PENDING_ACTIVATION',
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CHECK (expiry_month BETWEEN 1 AND 12),
    INDEX idx_card_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE card_controls (
    card_id BINARY(16) PRIMARY KEY,
    international_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    contactless_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    ecommerce_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    atm_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    daily_spend_limit DECIMAL(19,4) NOT NULL,
    changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    FOREIGN KEY (card_id) REFERENCES cards(id),
    CHECK (daily_spend_limit >= 0)
) ENGINE=InnoDB;

CREATE TABLE card_pin_history (
    id BINARY(16) PRIMARY KEY,
    card_id BINARY(16) NOT NULL,
    pin_hash VARCHAR(255) NOT NULL,
    changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (card_id) REFERENCES cards(id),
    INDEX idx_pin_history_card_changed (card_id, changed_at DESC)
) ENGINE=InnoDB;

CREATE TABLE reward_accounts (
    id BINARY(16) PRIMARY KEY,
    card_id BINARY(16) NOT NULL UNIQUE,
    points_balance BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    FOREIGN KEY (card_id) REFERENCES cards(id),
    CHECK (points_balance >= 0)
) ENGINE=InnoDB;

CREATE TABLE reward_transactions (
    id BINARY(16) PRIMARY KEY,
    reward_account_id BINARY(16) NOT NULL,
    transaction_reference VARCHAR(64) NOT NULL UNIQUE,
    points_delta BIGINT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (reward_account_id) REFERENCES reward_accounts(id),
    INDEX idx_reward_transaction_account (reward_account_id, created_at DESC)
) ENGINE=InnoDB;

CREATE TABLE outbox_events (
    id BINARY(16) PRIMARY KEY, aggregate_type VARCHAR(80) NOT NULL, aggregate_id BINARY(16) NOT NULL,
    event_type VARCHAR(120) NOT NULL, payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), published_at TIMESTAMP(6) NULL,
    INDEX idx_outbox_unpublished (published_at, occurred_at)
) ENGINE=InnoDB;
