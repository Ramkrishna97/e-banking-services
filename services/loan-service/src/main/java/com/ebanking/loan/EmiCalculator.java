package com.ebanking.loan;

import java.math.*;
import java.util.stream.IntStream;
import org.springframework.stereotype.Service;

@Service
public class EmiCalculator {
    public LoanQuote quote(BigDecimal principal, BigDecimal annualRate, int months) {
        if (principal == null || principal.signum() <= 0 || annualRate == null || annualRate.signum() < 0 || months < 1) throw new IllegalArgumentException("Invalid loan terms");
        BigDecimal monthlyRate = annualRate.divide(BigDecimal.valueOf(1200), 12, RoundingMode.HALF_EVEN);
        BigDecimal emi = monthlyRate.signum() == 0 ? principal.divide(BigDecimal.valueOf(months), 2, RoundingMode.HALF_EVEN)
                : principal.multiply(monthlyRate).multiply(BigDecimal.ONE.add(monthlyRate).pow(months))
                .divide(BigDecimal.ONE.add(monthlyRate).pow(months).subtract(BigDecimal.ONE), 2, RoundingMode.HALF_EVEN);
        return new LoanQuote(emi, emi.multiply(BigDecimal.valueOf(months)).subtract(principal));
    }
    public record LoanQuote(BigDecimal monthlyEmi, BigDecimal totalInterest) {}
}
