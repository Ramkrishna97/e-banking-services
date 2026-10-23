package com.ebanking.transfer;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.util.UUID;

@Service
class TransferService {
    Transfer submit(UUID requesterId, String idempotencyKey, CreateTransfer request) {
        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > 128)
            throw new InvalidIdempotencyKeyException();
        // This service must not claim a transfer was posted until it validates
        // the source account and atomically commits journal lines and an outbox event.
        throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "Transfer posting is unavailable until ledger integration is implemented");
    }

    record CreateTransfer(UUID sourceAccountId, String destinationAccountReference,
                          Transfer.Rail rail, BigDecimal amount) {}
}
