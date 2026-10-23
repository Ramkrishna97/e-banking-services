package com.ebanking.card;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/cards")
class CardController {
    private final CardRepository cards;
    private final CardControlsRepository controls;
    CardController(CardRepository cards, CardControlsRepository controls) {
        this.cards = cards; this.controls = controls;
    }

    @PostMapping @ResponseStatus(HttpStatus.CREATED) @Transactional
    CardView issue(@RequestHeader("X-Customer-Id") UUID customerId, @Valid @RequestBody IssueCard request) {
        Card card = cards.save(Card.issue(customerId, request.type()));
        CardControls state = new CardControls(); state.cardId = card.id; controls.save(state);
        return CardView.from(card, state);
    }

    @GetMapping
    CardView get(@RequestHeader("X-Customer-Id") UUID customerId, @RequestParam UUID id) {
        Card card = owned(id, customerId);
        return CardView.from(card, controls.findById(id).orElseThrow());
    }

    @PostMapping("/{id}/block") @Transactional
    CardView block(@RequestHeader("X-Customer-Id") UUID customerId, @PathVariable UUID id) {
        return changeStatus(id, customerId, Card.Status.BLOCKED);
    }

    @PostMapping("/{id}/unblock") @Transactional
    CardView unblock(@RequestHeader("X-Customer-Id") UUID customerId, @PathVariable UUID id) {
        return changeStatus(id, customerId, Card.Status.ACTIVE);
    }

    @PatchMapping("/{id}/controls") @Transactional
    CardView controls(@RequestHeader("X-Customer-Id") UUID customerId, @PathVariable UUID id,
                      @RequestBody ControlsRequest request) {
        Card card = owned(id, customerId);
        CardControls state = controls.findById(id).orElseThrow();
        if (request.internationalEnabled() != null) state.internationalEnabled = request.internationalEnabled();
        if (request.ecommerceEnabled() != null) state.ecommerceEnabled = request.ecommerceEnabled();
        return CardView.from(card, controls.save(state));
    }

    private CardView changeStatus(UUID id, UUID customerId, Card.Status status) {
        Card card = owned(id, customerId); card.status = status;
        return CardView.from(cards.save(card), controls.findById(id).orElseThrow());
    }

    private Card owned(UUID id, UUID customerId) {
        return cards.findByIdAndCustomerId(id, customerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));
    }

    record IssueCard(@NotNull Card.CardType type) {}
    record ControlsRequest(Boolean internationalEnabled, Boolean ecommerceEnabled) {}
    record CardView(UUID id, Card.CardType type, Card.Status status, boolean internationalEnabled,
                    boolean ecommerceEnabled, String lastFour) {
        static CardView from(Card card, CardControls state) {
            return new CardView(card.id, card.cardType, card.status, state.internationalEnabled,
                    state.ecommerceEnabled, card.lastFour);
        }
    }
}
