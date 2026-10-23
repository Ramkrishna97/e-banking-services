package com.ebanking.loan;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
@RestController @RequestMapping("/api/v1/loans")
class LoanController {
    private final EmiCalculator calculator; LoanController(EmiCalculator calculator) { this.calculator = calculator; }
    @PostMapping("/quote") EmiCalculator.LoanQuote quote(@Valid @RequestBody QuoteRequest request) { return calculator.quote(request.principal(), request.annualRate(), request.months()); }
    record QuoteRequest(@NotNull @DecimalMin("0.01") BigDecimal principal, @NotNull @DecimalMin("0.00") BigDecimal annualRate, @Min(1) @Max(480) int months) {}
}
