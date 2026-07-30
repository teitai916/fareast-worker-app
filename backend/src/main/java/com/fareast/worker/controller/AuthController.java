package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.dto.LoginRequest;
import com.fareast.worker.model.dto.RegisterRequest;
import com.fareast.worker.model.dto.ResetPasswordRequest;
import com.fareast.worker.model.dto.SmsRequest;
import com.fareast.worker.service.AuthService;
import com.fareast.worker.service.SmsService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    @Autowired
    private SmsService smsService;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/send-sms")
    public ApiResponse<Void> sendSms(@Valid @RequestBody SmsRequest request) {
        // 仅未注册的手机号才发送验证码，已注册也不提示差异（防手机号枚举）
        if (!userRepository.existsByPhone(request.getPhone())) {
            smsService.sendVerificationCode(request.getPhone());
        }
        return ApiResponse.success(null);
    }

    @PostMapping("/register")
    public ApiResponse<Map<String, Object>> register(@Valid @RequestBody RegisterRequest request) {
        Map<String, Object> result = authService.register(request);
        return ApiResponse.success(result);
    }

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@Valid @RequestBody LoginRequest request) {
        Map<String, Object> result = authService.login(request);
        return ApiResponse.success(result);
    }

    @PostMapping("/reset-password")
    public ApiResponse<Void> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
        return ApiResponse.success(null);
    }

    @PostMapping("/change-password")
    public ApiResponse<Void> changePassword(@AuthenticationPrincipal String userId,
                                            @RequestBody Map<String, String> body) {
        if (userId == null || userId.isBlank()) {
            return ApiResponse.error(401, "未登入或 token 已過期");
        }
        String newPassword = body.get("newPassword");
        if (newPassword == null || newPassword.trim().isEmpty()) {
            return ApiResponse.error(400, "新密碼不能為空");
        }
        authService.changePassword(Long.valueOf(userId), newPassword.trim());
        return ApiResponse.success(null);
    }

    @PostMapping("/refresh")
    public ApiResponse<Map<String, Object>> refresh(@RequestBody Map<String, String> request) {
        String refreshToken = request.get("refreshToken");
        Map<String, Object> result = authService.refresh(refreshToken);
        return ApiResponse.success(result);
    }

    @GetMapping("/me")
    public ApiResponse<User> me() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            return ApiResponse.error(401, "未登入或 token 已過期");
        }
        String userIdStr = (String) auth.getPrincipal();
        Long userId = Long.parseLong(userIdStr);
        User user = authService.getCurrentUser(userId);
        return ApiResponse.success(user);
    }

    /**
     * GET /auth/companies
     * 公開接口，註冊時獲取公司列表（判頭註冊時選擇所屬公司）
     */
    @GetMapping("/companies")
    public ApiResponse<List<Map<String, Object>>> getCompanies() {
        List<Company> companies = companyRepository.findAll();
        List<Map<String, Object>> data = companies.stream().map(c -> {
            Map<String, Object> m = new java.util.HashMap<>();
            m.put("id", c.getId());
            m.put("name", c.getName());
            m.put("contactPerson", c.getContactPerson());
            m.put("contactPhone", c.getContactPhone());
            m.put("type", c.getType() == null ? null : c.getType().name());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(data);
    }
}
