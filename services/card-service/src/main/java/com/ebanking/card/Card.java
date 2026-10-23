package com.ebanking.card;

import jakarta.persistence.*;
import java.time.YearMonth;
import java.util.UUID;

@Entity
@Table(name = "cards")
class Card {
    @Id UUID id;
    @Column(name = "card_reference", nullable = false, unique = true) String cardReference;
    @Column(name = "customer_id", nullable = false) UUID customerId;
    @Enumerated(EnumType.STRING) @Column(name = "card_type", nullable = false) CardType cardType;
    @Enumerated(EnumType.STRING) @Column(nullable = false) Network network = Network.RUPAY;
    @Column(name = "pan_token", nullable = false, unique = true) String panToken;
    @Column(name = "last_four", nullable = false, columnDefinition = "char(4)") String lastFour;
    @Column(name = "expiry_month", nullable = false) byte expiryMonth;
    @Column(name = "expiry_year", nullable = false) short expiryYear;
    @Enumerated(EnumType.STRING) @Column(nullable = false) Status status = Status.ACTIVE;
    enum CardType { DEBIT, CREDIT, VIRTUAL }
    enum Network { VISA, MASTERCARD, RUPAY }
    enum Status { PENDING_ACTIVATION, ACTIVE, BLOCKED, EXPIRED, CLOSED }

    static Card issue(UUID customerId, CardType type) {
        Card card = new Card();
        card.id = UUID.randomUUID();
        card.customerId = customerId;
        card.cardType = type;
        card.cardReference = "CARD-" + card.id.toString().replace("-", "").substring(0, 20).toUpperCase();
        card.panToken = UUID.randomUUID().toString();
        card.lastFour = String.format("%04d", Math.abs(card.id.hashCode()) % 10000);
        YearMonth expiration = YearMonth.now().plusYears(3);
        card.expiryMonth = (byte) expiration.getMonthValue();
        card.expiryYear = (short) expiration.getYear();
        return card;
    }
}
