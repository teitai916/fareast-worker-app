package com.fareast.worker.service;

import com.fareast.worker.model.dto.LoginRequest;
import com.fareast.worker.model.dto.RegisterRequest;
import com.fareast.worker.model.dto.ResetPasswordRequest;
import com.fareast.worker.model.entity.User;

import java.util.Map;

public interface AuthService {

    /**
     * Register a new worker account.
     * Returns a map containing "user" (User) and "token" (JWT string).
     */
    Map<String, Object> register(RegisterRequest request);

    /**
     * Authenticate with phone + password.
     * Returns a map containing "user" (User) and "token" (JWT string).
     */
    Map<String, Object> login(LoginRequest request);

    /**
     * Reset password after verifying SMS code.
     */
    void resetPassword(ResetPasswordRequest request);

    /**
     * Refresh JWT token using an existing valid token.
     */
    Map<String, Object> refresh(String refreshToken);

    /**
     * Get current user info by userId (extracted from JWT by the controller).
     */
    User getCurrentUser(Long userId);
}
