package com.ebanking.account;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.util.*;

@RestController @RequestMapping("/api/v1/accounts")
class AccountController {
    private final AccountRepository accounts;
    AccountController(AccountRepository accounts) { this.accounts = accounts; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    AccountView create(@RequestHeader("X-Customer-Id") UUID customerId, @Valid @RequestBody OpenAccount request) {
        if (!customerId.equals(request.customerId())) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer mismatch");
        Account account = new Account(); account.id = UUID.randomUUID(); account.customerId = request.customerId();
        account.accountType = request.type(); account.minimumBalance = request.minimumBalance();
        account.accountNumber = "EB" + String.format("%014d", Math.abs(UUID.randomUUID().getMostSignificantBits()) % 100_000_000_000_000L);
        return AccountView.from(accounts.save(account));
    }
    @GetMapping List<AccountView> portfolio(@RequestHeader("X-Customer-Id") UUID customerId) {
        return accounts.findByCustomerId(customerId).stream().map(AccountView::from).toList();
    }
    @PostMapping("/{id}/freeze") AccountView freeze(@PathVariable UUID id, @RequestHeader("X-Customer-Id") UUID customerId) {
        Account a = accounts.findByIdAndCustomerId(id, customerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Account not found"));
        a.status = Account.AccountStatus.FROZEN; return AccountView.from(accounts.save(a));
    }
    record OpenAccount(@NotNull UUID customerId, @NotNull Account.AccountType type, @NotNull @DecimalMin("0.00") BigDecimal minimumBalance) {}
    record AccountView(UUID id, String accountNumber, Account.AccountType type, Account.AccountStatus status, BigDecimal availableBalance) {
        static AccountView from(Account a) { return new AccountView(a.id, a.accountNumber, a.accountType, a.status, a.availableBalance); }
    }
}
