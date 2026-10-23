package com.ebanking.authkyc;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
@Service class TokenService {
 private final String secret; TokenService(@Value("${security.jwt.secret}") String secret) { this.secret=secret; }
 String access(Customer c) { return token(c,"access",900); } String refresh(Customer c) { return token(c,"refresh",604800); }
 private String token(Customer c,String type,long ttl) { String h=b64("{\"alg\":\"HS256\",\"typ\":\"JWT\"}"); String p=b64("{\"sub\":\""+c.id+"\",\"role\":\""+c.role+"\",\"typ\":\""+type+"\",\"exp\":"+(Instant.now().getEpochSecond()+ttl)+"}"); return h+"."+p+"."+sign(h+"."+p); }
 private String sign(String value) { try { Mac mac=Mac.getInstance("HmacSHA256"); mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8),"HmacSHA256")); return Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(value.getBytes(StandardCharsets.UTF_8))); } catch(Exception e) { throw new IllegalStateException(e); } }
 private String b64(String value) { return Base64.getUrlEncoder().withoutPadding().encodeToString(value.getBytes(StandardCharsets.UTF_8)); }
}
