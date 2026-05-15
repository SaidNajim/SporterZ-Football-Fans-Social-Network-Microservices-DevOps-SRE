package com.example.Auth;

import com.example.Auth.services.JwtService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.context.TestPropertySource;

import java.security.Key;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class JwtServiceTest {

    private JwtService jwtService;

    @Mock
    private UserDetails userDetails;

    private static final String SECRET_KEY = "10040A2526072B667C02EE4AE6A75D115E7F7E02573892D5BD3C4A9E9B2B4C3AFF868172859CFC44B72360563C8BA66D"; // pragma: allowlist secret
    private static final String TEST_USERNAME = "testUser";

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        jwtService = new JwtService();
        when(userDetails.getUsername()).thenReturn(TEST_USERNAME);
    }

    @Test
    void testGenerateToken() {
        String token = jwtService.generateToken(userDetails);
        assertNotNull(token);
        assertTrue(token.length() > 0);
        assertEquals(2, token.chars().filter(ch -> ch == '.').count());
    }

    @Test
    void testGenerateTokenWithExtraClaims() {
        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("role", "admin");

        String token = jwtService.generateToken(extraClaims, userDetails);
        assertNotNull(token);
        assertTrue(token.length() > 0);

        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();

        assertEquals(TEST_USERNAME, claims.getSubject());
        assertEquals("admin", claims.get("role"));
    }

    @Test
    void testExtractUsername() {
        String token = jwtService.generateToken(userDetails);
        String username = jwtService.extractUsername(token);
        assertEquals(TEST_USERNAME, username);
    }

    @Test
    void testExtractClaim() {
        String token = jwtService.generateToken(userDetails);
        String subject = jwtService.extractClaim(token, Claims::getSubject);
        assertEquals(TEST_USERNAME, subject);
    }

    @Test
    void testIsTokenValid() {
        String token = jwtService.generateToken(userDetails);
        assertTrue(jwtService.isTokenValid(token, userDetails));
    }

    private Key getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_KEY);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
