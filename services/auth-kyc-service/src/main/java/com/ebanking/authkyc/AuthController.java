package com.ebanking.authkyc;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
class AuthController {
    private final CustomerRepository customers;
    private final PasswordEncoder encoder;
    private final TokenService tokens;

    AuthController(CustomerRepository customers, PasswordEncoder encoder, TokenService tokens) {
        this.customers = customers;
        this.encoder = encoder;
        this.tokens = tokens;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    TokenResponse register(@Valid @RequestBody Registration request) {
        if (customers.findByEmail(request.email()).isPresent())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email exists");
        Customer customer = new Customer();
        customer.id = UUID.randomUUID();
        customer.customerReference = "C" + customer.id.toString().replace("-", "").substring(0, 20).toUpperCase();
        customer.email = request.email();
        customer.mobileNumber = request.mobileNumber();
        customer.legalName = request.legalName();
        customer.dateOfBirth = request.dateOfBirth();
        customer.customerType = Customer.CustomerType.RETAIL;
        customer.passwordHash = encoder.encode(request.password());
        return issue(customers.save(customer));
    }

    @PostMapping("/login")
    TokenResponse login(@Valid @RequestBody Credentials request) {
        Customer customer = customers.findByEmail(request.email())
                .filter(value -> encoder.matches(request.password(), value.passwordHash))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials"));
        if (customer.mfaEnabled)
            throw new ResponseStatusException(HttpStatus.PRECONDITION_REQUIRED, "MFA challenge required");
        return issue(customer);
    }

    @PostMapping("/mfa/verify")
    TokenResponse verifyMfa(@RequestParam UUID customerId, @RequestParam @Pattern(regexp = "\\d{6}") String otp) {
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No enrolled MFA factor is available");
    }

    private TokenResponse issue(Customer customer) {
        return new TokenResponse(customer.id, tokens.access(customer), tokens.refresh(customer), Instant.now().plusSeconds(900));
    }

    record Registration(@Email @NotBlank String email, @Size(min = 12, max = 128) String password,
                        @NotBlank String legalName, @NotBlank String mobileNumber, @NotNull LocalDate dateOfBirth) {}
    record Credentials(@Email String email, @Size(min = 12, max = 128) String password) {}
    record TokenResponse(UUID customerId, String accessToken, String refreshToken, Instant expiresAt) {}
}
