package com.ebanking.transfer;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.util.UUID;
@RestController @RequestMapping("/api/v1/transfers")
class TransferController {
    private final TransferService service; TransferController(TransferService service) { this.service = service; }
    @PostMapping ResponseEntity<TransferView> transfer(@RequestHeader("X-Customer-Id") UUID customerId, @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody Request request) {
        Transfer t = service.submit(customerId, key, new TransferService.CreateTransfer(request.sourceAccountId(), request.destinationAccountReference(), request.rail(), request.amount()));
        return ResponseEntity.status(HttpStatus.CREATED).body(TransferView.from(t));
    }
    record Request(@NotNull UUID sourceAccountId, @NotBlank String destinationAccountReference, @NotNull Transfer.Rail rail, @NotNull @DecimalMin("0.01") BigDecimal amount) {}
    record TransferView(String reference, Transfer.Status status, BigDecimal amount, Transfer.Rail rail) { static TransferView from(Transfer t) { return new TransferView(t.transferReference, t.status, t.amount, t.rail); } }
}
