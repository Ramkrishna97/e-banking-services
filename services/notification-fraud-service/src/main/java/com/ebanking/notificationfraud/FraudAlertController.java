package com.ebanking.notificationfraud;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController @RequestMapping("/api/v1/fraud-alerts")
class FraudAlertController {
    private final List<Alert> alerts = new CopyOnWriteArrayList<>();
    @PostMapping Alert evaluate(@RequestHeader("X-Customer-Id") UUID customerId, @Valid @RequestBody TransactionSignal signal) {
        if (!customerId.equals(signal.customerId())) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer mismatch");
        boolean suspicious = signal.amount() > 100_000 || signal.newGeography() || signal.eventsLastHour() > 5;
        Alert alert = new Alert(UUID.randomUUID(), signal.customerId(), suspicious ? "HIGH" : "LOW", suspicious ? "Velocity or unusual geography" : "No anomaly", Instant.now()); alerts.add(alert); return alert;
    }
    @GetMapping List<Alert> all(@RequestHeader("X-Customer-Id") UUID authenticatedCustomerId, @RequestParam UUID customerId) { if (!authenticatedCustomerId.equals(customerId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer mismatch"); return alerts.stream().filter(a -> a.customerId().equals(customerId)).toList(); }
    record TransactionSignal(@NotNull UUID customerId, @PositiveOrZero long amount, boolean newGeography, @Min(0) int eventsLastHour) {}
    record Alert(UUID id, UUID customerId, String severity, String reason, Instant raisedAt) {}
}
