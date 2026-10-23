package com.ebanking.transfer;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.net.URI;
class InvalidIdempotencyKeyException extends RuntimeException {}
@RestControllerAdvice class ApiExceptionHandler {
    @ExceptionHandler({InvalidIdempotencyKeyException.class, IllegalArgumentException.class}) ProblemDetail invalid(RuntimeException error) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, error.getMessage() == null ? "Invalid request" : error.getMessage()); p.setType(URI.create("urn:ebanking:invalid-request")); return p;
    }
}
