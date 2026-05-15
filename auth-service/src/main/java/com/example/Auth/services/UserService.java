package com.example.Auth.services;

import com.example.Auth.models.FriendRequest;
import com.example.Auth.models.User;
import com.example.Auth.repositories.UserRepository;
import io.jsonwebtoken.Claims;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@Service
public class UserService {

    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final UserRepository userRepository;
    public UserService(JwtService jwtService, PasswordEncoder passwordEncoder, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
    }

    public User getUser(String token) {
        String email = jwtService.extractClaim(token, Claims::getSubject);
        return userRepository.findByEmail(email).orElseThrow();
    }

    public ResponseEntity<Map<String, String>> getCurrentUser(String token) {
        User currentUser = getUser(token);
        String email = currentUser.getEmail();
        String login = currentUser.getLogin();
        String firstname = currentUser.getFirstName();
        String lastname = currentUser.getLastName();
        String picture = currentUser.getPhoto();

        Map<String, String> userData = new HashMap<>();
        userData.put("email", email);
        userData.put("login", login);
        userData.put("firstName", firstname);
        userData.put("lastName", lastname);
        userData.put("photo", picture);

        return ResponseEntity.ok(userData);
    }

    public User updateUser(User user, String token) {
        User updatedUser = getUser(String.valueOf(token));
        Optional<User> existingUserOptional = userRepository.findById(updatedUser.getUserId());
        if (existingUserOptional.isPresent()) {
            User existingUser = existingUserOptional.get();

            if (user.getEmail() != null) {
                existingUser.setEmail(user.getEmail());
            }
            if (user.getLogin() != null) {
                existingUser.setLogin(user.getLogin());
            }
            if (user.getFirstName() != null) {
                existingUser.setFirstName(user.getFirstName());
            }
            if (user.getLastName() != null) {
                existingUser.setLastName(user.getLastName());
            }

            if (user.getPhoto() != null) {
                existingUser.setPhoto(user.getPhoto());
            }
            if (user.getPassword() != null) {
                existingUser.setPassword(passwordEncoder.encode(user.getPassword()));
            }
            if (user.getRole() != null) {
                existingUser.setRole(user.getRole());
            }

            return userRepository.save(existingUser);
        } else {
            return null;
        }
    }

    public void addFriend(FriendRequest friendRequest) {
        User actualUser = userRepository.findById(friendRequest.getActualUserId()).orElseThrow();
        User friendUser = userRepository.findById(friendRequest.getFriendUserId()).orElseThrow();

        actualUser.getFriends().add(friendUser);
        //friendUser.getFriends().add(actualUser);
        userRepository.save(actualUser);
        //userRepository.save(friendUser);
    }
}
