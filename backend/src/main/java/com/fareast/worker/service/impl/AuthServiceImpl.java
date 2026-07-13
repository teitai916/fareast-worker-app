package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.LoginRequest;
import com.fareast.worker.model.dto.RegisterRequest;
import com.fareast.worker.model.dto.ResetPasswordRequest;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.model.enums.UserStatus;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.security.JwtTokenProvider;
import com.fareast.worker.service.AuthService;
import com.fareast.worker.service.SmsService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class AuthServiceImpl implements AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private SmsService smsService;

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @Override
    @Transactional
    public Map<String, Object> register(RegisterRequest request) {
        // Verify SMS code
        boolean codeValid = smsService.verifyCode(request.getPhone(), request.getVerificationCode());
        if (!codeValid) {
            throw new BusinessException(400, "驗證碼錯誤或已過期");
        }

        // Check phone uniqueness
        if (userRepository.existsByPhone(request.getPhone())) {
            throw new BusinessException(400, "該手機號碼已被註冊");
        }

        // Create user
        User.UserBuilder userBuilder = User.builder()
                .phone(request.getPhone())
                .countryCode(request.getCountryCode() != null ? request.getCountryCode() : "+852")
                .password(passwordEncoder.encode(request.getPassword()))
                .name(request.getChineseName())   // 中文姓名
                .englishName(request.getEnglishName()) // 英文姓名
                .role(parseRole(request.getRole()))
                .status(UserStatus.ACTIVE);

        // 判頭註冊時設置所屬公司
        if (request.getCompanyId() != null) {
            userBuilder.companyId(request.getCompanyId());
        }

        User user = userBuilder.build();
        user = userRepository.save(user);
        log.info("新用戶註冊成功: userId={}, phone={}, name={}", user.getId(), user.getPhone(), user.getName());

        // 判頭註冊時，更新 companies.user_id（雙向綁定）
        if (parseRole(request.getRole()) == UserRole.CONTRACTOR && request.getCompanyId() != null) {
            Long userId = user.getId();  // effectively final，可在 lambda 中使用
            companyRepository.findById(request.getCompanyId()).ifPresent(company -> {
                company.setUserId(userId);
                companyRepository.save(company);
                log.info("公司已綁定判頭: companyId={}, userId={}", company.getId(), userId);
            });
        }

        // 只有工人角色才创建 WorkerProfile
        if (parseRole(request.getRole()) == UserRole.WORKER) {
            String workerNumber = generateWorkerNumber();
            WorkerProfile.WorkerProfileBuilder profileBuilder = WorkerProfile.builder()
                    .userId(user.getId())
                    .chineseName(request.getChineseName())
                    .englishName(request.getEnglishName())
                    .workerNumber(workerNumber)
                    .blacklisted(false)
                    .cardLocked(false)
                    .faceRegistered(false);

            // 出生日期（工人注册时必填）
            if (request.getBirthDate() != null && !request.getBirthDate().isBlank()) {
                try {
                    profileBuilder.birthDate(LocalDate.parse(request.getBirthDate()));
                } catch (Exception e) {
                    throw new BusinessException(400, "出生日期格式不正確，請使用 yyyy-MM-dd");
                }
            }

            WorkerProfile profile = profileBuilder.build();
            workerProfileRepository.save(profile);
            log.info("工人資料已創建: userId={}, workerNumber={}", user.getId(), workerNumber);
        } else {
            log.info("非工人角色，跳過 WorkerProfile 創建: userId={}, role={}", user.getId(), request.getRole());
        }

        // Generate JWT
        String token = generateTokenForUser(user);

        Map<String, Object> result = new HashMap<>();
        result.put("user", user);
        result.put("token", token);
        return result;
    }

    @Override
    public Map<String, Object> login(LoginRequest request) {
        // 暴力破解防护：检查失败计数
        String failKey = "login:fail:" + request.getPhone();
        String failCountStr = redisTemplate.opsForValue().get(failKey);
        int failCount = failCountStr != null ? Integer.parseInt(failCountStr) : 0;

        if (failCount >= 5) {
            Long ttl = redisTemplate.getExpire(failKey, TimeUnit.SECONDS);
            long remainMin = Math.max(1, (ttl != null ? ttl : 1800) / 60);
            throw new BusinessException(429, "登录尝试次数过多，请" + remainMin + "分钟后重试");
        }

        // Find user
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> {
                    // 用户不存在也计入失败
                    recordLoginFail(failKey);
                    return new BusinessException(400, "手機號碼未註冊");
                });

        // Verify password
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            recordLoginFail(failKey);
            throw new BusinessException(401, "密碼錯誤");
        }

        // 登录成功，清除失败计数
        redisTemplate.delete(failKey);

        // Check status
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BusinessException(403, "帳號已被停用");
        }

        // Update last login time
        user.setLastLoginTime(LocalDateTime.now());
        userRepository.save(user);

        // Authenticate via Spring Security
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getPhone(), request.getPassword())
        );
        String token = jwtTokenProvider.generateToken(authentication);

        log.info("用戶登入成功: userId={}, phone={}", user.getId(), user.getPhone());

        Map<String, Object> result = new HashMap<>();
        result.put("user", user);
        result.put("token", token);
        return result;
    }

    /**
     * 记录登录失败次数，30分钟内连续5次失败后锁定
     */
    private void recordLoginFail(String failKey) {
        String failCountStr = redisTemplate.opsForValue().get(failKey);
        int count = failCountStr != null ? Integer.parseInt(failCountStr) : 0;
        redisTemplate.opsForValue().set(failKey, String.valueOf(count + 1), 30, TimeUnit.MINUTES);
    }

    @Override
    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        // Verify SMS code
        boolean codeValid = smsService.verifyCode(request.getPhone(), request.getVerificationCode());
        if (!codeValid) {
            throw new BusinessException(400, "驗證碼錯誤或已過期");
        }

        // Find user
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> new BusinessException(400, "手機號碼未註冊"));

        // Update password
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        log.info("密碼重設成功: userId={}, phone={}", user.getId(), user.getPhone());
    }

    @Override
    public Map<String, Object> refresh(String refreshToken) {
        // Validate the existing token
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new BusinessException(401, "令牌無效或已過期");
        }

        // Extract userId
        String userIdStr = jwtTokenProvider.getUserIdFromToken(refreshToken);
        Long userId = Long.parseLong(userIdStr);

        // Find user
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(400, "用戶不存在"));

        // Generate new token
        String newToken = generateTokenForUser(user);

        Map<String, Object> result = new HashMap<>();
        result.put("user", user);
        result.put("token", newToken);
        return result;
    }

    @Override
    public User getCurrentUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
    }

    /**
     * Parse role string to UserRole enum.
     * Defaults to WORKER if the string is null/blank or invalid.
     */
    private UserRole parseRole(String roleStr) {
        if (roleStr == null || roleStr.isBlank()) return UserRole.WORKER;
        try {
            return UserRole.valueOf(roleStr.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return UserRole.WORKER;
        }
    }

    /**
     * Helper to create a JWT for a user entity without going through
     * the full AuthenticationManager flow.
     */
    private String generateTokenForUser(User user) {
        UserDetails userDetails = new org.springframework.security.core.userdetails.User(
                user.getId().toString(),
                user.getPassword(),
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()))
        );
        Authentication authentication = new UsernamePasswordAuthenticationToken(
                userDetails, null, userDetails.getAuthorities()
        );
        return jwtTokenProvider.generateToken(authentication);
    }

    /**
     * Generate unique worker number: YW + yyyyMMdd + 3-digit sequence
     * e.g. YW20250605-001
     */
    private String generateWorkerNumber() {
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        // Count existing workers registered today
        List<WorkerProfile> today = workerProfileRepository.findAll().stream()
                .filter(p -> p.getWorkerNumber() != null && p.getWorkerNumber().contains(dateStr))
                .toList();
        int seq = today.size() + 1;
        return String.format("YW%s-%03d", dateStr, seq);
    }
}
