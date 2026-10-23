package com.ebanking.authkyc;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
@Configuration @EnableWebSecurity class SecurityConfig {
 @Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(12); }
 @Bean SecurityFilterChain security(HttpSecurity http) throws Exception { return http.csrf(c->c.disable()).authorizeHttpRequests(a->a.requestMatchers("/api/v1/auth/**","/actuator/health","/error").permitAll().anyRequest().authenticated()).build(); }
}
