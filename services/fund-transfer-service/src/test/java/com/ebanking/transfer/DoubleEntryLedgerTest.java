package com.ebanking.transfer;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.UUID;
import static org.assertj.core.api.Assertions.*;
class DoubleEntryLedgerTest {
    private final DoubleEntryLedger ledger = new DoubleEntryLedger();
    @Test void creates_balanced_debit_and_credit_lines() {
        var lines = ledger.post(new BigDecimal("100.25"), UUID.randomUUID(), "DESTINATION");
        assertThat(lines).hasSize(2); assertThat(lines.get(0).amount()).isEqualByComparingTo(lines.get(1).amount());
    }
    @Test void rejects_non_positive_money() { assertThatIllegalArgumentException().isThrownBy(() -> ledger.post(BigDecimal.ZERO, UUID.randomUUID(), "DESTINATION")); }
}
