package com.example.matchservice.Service;

import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Service
public class FootballApi {
    private static String apiKey;
    @Value("${apisports.key}")
    public void setApiKey(String apiKey) {
        FootballApi.apiKey = apiKey;
    }
    private final static String url = "https://v3.football.api-sports.io";
    private static final String twoDaysAgo = LocalDate.now().minusDays(2).format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
    private static final String fiveDaysAfter = LocalDate.now().plusDays(5).format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));

    public static JSONObject getBoardMatches(int league) {
        try {
            String data = WebClient.builder()
                    .baseUrl(url)
                    .defaultHeader("x-apisports-key", apiKey)
                    .build()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/fixtures")
                            .queryParam("league", league)
                            .queryParam("season", "2023")
                            .queryParam("from", twoDaysAgo)
                            .queryParam("to", fiveDaysAfter)
                            .build())
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            return new JSONObject(data);
        } catch (Exception e) {
            return new JSONObject().put("error", e.getMessage());
        }
    }

}
