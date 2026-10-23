package com.ebanking.transfer;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.stereotype.Component;

@Component
public class DoubleEntryLedger {
    public List<JournalLine> post(BigDecimal amount, UUID debitAccount, String creditAccount) {
        if (amount == null || amount.signum() <= 0) throw new IllegalArgumentException("Transfer amount must be positive");
        List<JournalLine> lines = List.of(new JournalLine(debitAccount.toString(), EntrySide.DEBIT, amount), new JournalLine(creditAccount, EntrySide.CREDIT, amount));
        BigDecimal debit = lines.stream().filter(l -> l.side() == EntrySide.DEBIT).map(JournalLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = lines.stream().filter(l -> l.side() == EntrySide.CREDIT).map(JournalLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        if (debit.compareTo(credit) != 0) throw new IllegalStateException("Unbalanced journal rejected");
        return lines;
    }
    public enum EntrySide { DEBIT, CREDIT }
    public record JournalLine(String ledgerAccount, EntrySide side, BigDecimal amount) {}
}
