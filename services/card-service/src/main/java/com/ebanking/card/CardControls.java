package com.ebanking.card;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "card_controls")
class CardControls {
    @Id @Column(name = "card_id") UUID cardId;
    @Column(name = "international_enabled", nullable = false) boolean internationalEnabled = false;
    @Column(name = "ecommerce_enabled", nullable = false) boolean ecommerceEnabled = true;
    @Column(name = "contactless_enabled", nullable = false) boolean contactlessEnabled = true;
    @Column(name = "atm_enabled", nullable = false) boolean atmEnabled = true;
    @Column(name = "daily_spend_limit", nullable = false, precision = 19, scale = 4) BigDecimal dailySpendLimit = new BigDecimal("50000.0000");
}
