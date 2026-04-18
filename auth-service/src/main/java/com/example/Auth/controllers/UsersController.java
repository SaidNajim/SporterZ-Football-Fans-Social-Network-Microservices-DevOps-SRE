package com.example.Auth.controllers;

import com.example.Auth.models.FriendRequest;
import com.example.Auth.models.User;
import com.example.Auth.repositories.UserRepository;
import com.example.Auth.services.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class UsersController {

    private final UserService userService;

    private final UserRepository userRepository;
    @GetMapping("/getAll")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, String>> getCurrentUser(@RequestHeader("Authorization") String authorizationHeader) {
        String token = extractTokenFromHeader(authorizationHeader);
        return userService.getCurrentUser(token);
    }

    private String extractTokenFromHeader(String authorizationHeader) {
        if (authorizationHeader != null && authorizationHeader.startsWith("Bearer ")) {
            return authorizationHeader.substring(7);
        }
        return null;
    }

    @PostMapping("/update")
    public ResponseEntity<User> updateUser(@RequestBody User user, @RequestHeader("Authorization") String authorizationHeader) {
        String token = extractTokenFromHeader(authorizationHeader);
        userService.updateUser(user, token);
        return ResponseEntity.status(200).build();
    }

    @PostMapping("/addFriend")
    public void addFriend(@RequestBody FriendRequest friendRequest) {
        userService.addFriend(friendRequest);
    }

    @GetMapping("/getFriends")
    public ResponseEntity<List<User>> getFriends(@RequestParam Long actualUserId) {
        return ResponseEntity.ok(userRepository.findById(actualUserId).get().getFriends());
    }
}
