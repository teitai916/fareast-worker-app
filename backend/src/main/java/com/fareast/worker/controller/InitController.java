package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.model.enums.UserStatus;
import com.fareast.worker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 开发/运维初始化接口（仅内部 LAN 使用，无公网暴露）
 */
@RestController
@RequestMapping("/init")
public class InitController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * POST /init/internal-user
     * 创建内部管理人员账号（免短信验证）
     * 请求体: { phone, password, name, role }
     * role 仅允许: SUPER_ADMIN / SAFETY_OFFICER / PROJECT_MANAGER / SITE_MANAGER / INSTALL_MANAGER / NOTIFIED_PARTY
     */
    @PostMapping("/internal-user")
    public ApiResponse<Map<String, Object>> createInternalUser(@RequestBody Map<String, String> body) {
        String phone = body.get("phone");
        String password = body.get("password");
        String name = body.get("name");
        String roleStr = body.get("role");

        // 参数校验
        if (phone == null || phone.isBlank()) {
            return ApiResponse.error(400, "手机号不能为空");
        }
        phone = phone.trim();

        if (password == null || password.isBlank()) {
            return ApiResponse.error(400, "密码不能为空");
        }
        password = password.trim();

        if (name == null || name.isBlank()) {
            return ApiResponse.error(400, "姓名不能为空");
        }
        name = name.trim();

        if (roleStr == null || roleStr.isBlank()) {
            return ApiResponse.error(400, "角色不能为空");
        }
        roleStr = roleStr.trim().toUpperCase();

        // 角色校验：仅允许内部管理角色
        UserRole role;
        try {
            role = UserRole.valueOf(roleStr);
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, "无效角色: " + roleStr);
        }

        if (role == UserRole.WORKER || role == UserRole.CONTRACTOR) {
            return ApiResponse.error(400, "工人/判头请使用「快速创建账号」标签页注册，此接口仅用于内部管理人员");
        }

        // 手机号唯一性
        if (userRepository.existsByPhone(phone)) {
            return ApiResponse.error(409, "该手机号已注册: " + phone);
        }

        // BCrypt 加密密码
        String encodedPassword = passwordEncoder.encode(password);

        // 创建用户
        User user = User.builder()
                .phone(phone)
                .password(encodedPassword)
                .name(name)
                .role(role)
                .status(UserStatus.ACTIVE)
                .build();

        User saved = userRepository.save(user);

        Map<String, Object> result = new java.util.HashMap<>();
        result.put("id", saved.getId());
        result.put("phone", saved.getPhone());
        result.put("name", saved.getName());
        result.put("role", saved.getRole().name());

        return ApiResponse.success("内部人员账号创建成功", result);
    }
}
