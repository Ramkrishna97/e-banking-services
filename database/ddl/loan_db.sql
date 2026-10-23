CREATE DATABASE IF NOT EXISTS loan_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE loan_db;

CREATE TABLE loan_products (
    id BINARY(16) PRIMARY KEY,
    product_code VARCHAR(32) NOT NULL UNIQUE,
    loan_type ENUM('PERSONAL','HOME','AUTO') NOT NULL,
    minimum_amount DECIMAL(19,4) NOT NULL,
    maximum_amount DECIMAL(19,4) NOT NULL,
    annual_interest_rate DECIMAL(7,4) NOT NULL,
    minimum_tenure_months SMALLINT NOT NULL,
    maximum_tenure_months SMALLINT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (minimum_amount > 0 AND maximum_amount >= minimum_amount),
    CHECK (annual_interest_rate >= 0)
) ENGINE=InnoDB;

CREATE TABLE loan_applications (
    id BINARY(16) PRIMARY KEY,
    application_reference VARCHAR(40) NOT NULL UNIQUE,
    customer_id BINARY(16) NOT NULL,
    product_id BINARY(16) NOT NULL,
    requested_amount DECIMAL(19,4) NOT NULL,
    tenure_months SMALLINT NOT NULL,
    declared_monthly_income DECIMAL(19,4) NOT NULL,
    credit_score SMALLINT NULL,
    status ENUM('DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
    decision_reason VARCHAR(500) NULL,
    submitted_at TIMESTAMP(6) NULL,
    decided_at TIMESTAMP(6) NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (product_id) REFERENCES loan_products(id),
    CHECK (requested_amount > 0),
    INDEX idx_application_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE loans (
    id BINARY(16) PRIMARY KEY,
    loan_account_number CHAR(16) NOT NULL UNIQUE,
    application_id BINARY(16) NOT NULL UNIQUE,
    customer_id BINARY(16) NOT NULL,
    disbursement_account_id BINARY(16) NOT NULL,
    principal_amount DECIMAL(19,4) NOT NULL,
    annual_interest_rate DECIMAL(7,4) NOT NULL,
    tenure_months SMALLINT NOT NULL,
    emi_amount DECIMAL(19,4) NOT NULL,
    outstanding_principal DECIMAL(19,4) NOT NULL,
    status ENUM('APPROVED','DISBURSED','ACTIVE','CLOSED','DEFAULTED') NOT NULL DEFAULT 'APPROVED',
    disbursed_at TIMESTAMP(6) NULL,
    FOREIGN KEY (application_id) REFERENCES loan_applications(id),
    CHECK (principal_amount > 0 AND emi_amount > 0),
    INDEX idx_loan_customer_status (customer_id, status)
) ENGINE=InnoDB;

CREATE TABLE emi_schedule (
    id BINARY(16) PRIMARY KEY,
    loan_id BINARY(16) NOT NULL,
    installment_number SMALLINT NOT NULL,
    due_date DATE NOT NULL,
    opening_principal DECIMAL(19,4) NOT NULL,
    principal_component DECIMAL(19,4) NOT NULL,
    interest_component DECIMAL(19,4) NOT NULL,
    total_due DECIMAL(19,4) NOT NULL,
    paid_amount DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    status ENUM('PENDING','PAID','OVERDUE','WAIVED') NOT NULL DEFAULT 'PENDING',
    UNIQUE KEY uq_emi_loan_installment (loan_id, installment_number),
    FOREIGN KEY (loan_id) REFERENCES loans(id),
    CHECK (principal_component >= 0 AND interest_component >= 0)
) ENGINE=InnoDB;

CREATE TABLE outbox_events (
    id BINARY(16) PRIMARY KEY, aggregate_type VARCHAR(80) NOT NULL, aggregate_id BINARY(16) NOT NULL,
    event_type VARCHAR(120) NOT NULL, payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), published_at TIMESTAMP(6) NULL,
    INDEX idx_outbox_unpublished (published_at, occurred_at)
) ENGINE=InnoDB;
