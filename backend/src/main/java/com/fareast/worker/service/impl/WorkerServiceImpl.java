package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.WorkerRegisterRequest;
import com.fareast.worker.model.entity.SafetyDeduction;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.repository.SafetyDeductionRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.service.FaceVerificationService;
import com.fareast.worker.service.WorkerService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
public class WorkerServiceImpl implements WorkerService {

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SafetyDeductionRepository safetyDeductionRepository;

    @Autowired
    private FaceVerificationService faceVerificationService;

    @Value("${face.verification-threshold:60}")
    private int verificationThreshold;

    @Value("${file.upload-dir:./uploads}")
    private String uploadDir;

    @Override
    public WorkerProfile getProfile(Long userId) {
        return workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
    }

    /**
     * Get profile, creating one if it doesn't exist.
     * Used after registration.
     */
    public WorkerProfile getOrCreateProfile(Long userId) {
        return workerProfileRepository.findByUserId(userId).orElseGet(() -> {
            WorkerProfile profile = WorkerProfile.builder()
                    .userId(userId)
                    .blacklisted(false)
                    .cardLocked(false)
                    .faceRegistered(false)
                    .build();
            return workerProfileRepository.save(profile);
        });
    }

    @Override
    @Transactional
    public Map<String, Object> registerWorker(WorkerRegisterRequest request) {
        // Find user by phone (assumes user already exists via AuthController register)
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> new BusinessException(400, "用戶不存在，請先註冊帳號"));

        Long userId = user.getId();

        WorkerProfile profile = workerProfileRepository.findByUserId(userId).orElse(null);

        if (profile == null) {
            profile = WorkerProfile.builder()
                    .userId(userId)
                    .chineseName(request.getChineseName())
                    .englishName(request.getEnglishName())
                    .safetyCard(request.getSafetyCard())
                    .workerRegistrationNum(request.getWorkerRegistrationNum())
                    .dailyWage(request.getDailyWage())
                    .blacklisted(false)
                    .cardLocked(false)
                    .faceRegistered(false)
                    .build();
        } else {
            if (request.getChineseName() != null) profile.setChineseName(request.getChineseName());
            if (request.getEnglishName() != null) profile.setEnglishName(request.getEnglishName());
            if (request.getSafetyCard() != null) profile.setSafetyCard(request.getSafetyCard());
            if (request.getWorkerRegistrationNum() != null)
                profile.setWorkerRegistrationNum(request.getWorkerRegistrationNum());
            if (request.getDailyWage() != null) profile.setDailyWage(request.getDailyWage());
        }

        profile = workerProfileRepository.save(profile);
        log.info("工人資料已保存: userId={}, profileId={}", userId, profile.getId());

        Map<String, Object> result = new HashMap<>();
        result.put("profile", profile);
        result.put("userId", userId);
        return result;
    }

    /*
     * 人脸识别功能已注释（App Store 合规要求）
    @Override
    @Transactional
    public Map<String, Object> registerFace(Long userId, MultipartFile faceImage) {
        // ... face registration logic ...
    }

    @Override
    @Transactional
    public Map<String, Object> registerFaceBase64(Long userId, String base64Image) {
        // ... face base64 registration logic ...
    }

    @Override
    public Map<String, Object> verifyFace(Long userId, String liveBase64) {
        // ... face verification logic ...
    }
    */

    @Override
    public Page<SafetyDeduction> getDeductions(Long userId, int page, int size) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
        return safetyDeductionRepository.findByWorkerId(profile.getId(), PageRequest.of(page, size));
    }
}
