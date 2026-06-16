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
                    .safetyScore(100)
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
                    .hkid(request.getHkid())
                    .safetyCard(request.getSafetyCard())
                    .workerRegistrationNum(request.getWorkerRegistrationNum())
                    .dailyWage(request.getDailyWage())
                    .currentSiteId(request.getSiteId())
                    .safetyScore(100)
                    .blacklisted(false)
                    .cardLocked(false)
                    .faceRegistered(false)
                    .build();
        } else {
            if (request.getChineseName() != null) profile.setChineseName(request.getChineseName());
            if (request.getEnglishName() != null) profile.setEnglishName(request.getEnglishName());
            if (request.getHkid() != null) profile.setHkid(request.getHkid());
            if (request.getSafetyCard() != null) profile.setSafetyCard(request.getSafetyCard());
            if (request.getWorkerRegistrationNum() != null)
                profile.setWorkerRegistrationNum(request.getWorkerRegistrationNum());
            if (request.getDailyWage() != null) profile.setDailyWage(request.getDailyWage());
            if (request.getSiteId() != null) profile.setCurrentSiteId(request.getSiteId());
        }

        profile = workerProfileRepository.save(profile);
        log.info("工人資料已保存: userId={}, profileId={}", userId, profile.getId());

        Map<String, Object> result = new HashMap<>();
        result.put("profile", profile);
        result.put("userId", userId);
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> registerFace(Long userId, MultipartFile faceImage) {
        if (faceImage == null || faceImage.isEmpty()) {
            throw new BusinessException(400, "請上傳人臉圖片");
        }

        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        // Mock: return a mock face image URL
        String imageUrl = "/uploads/faces/mock_" + userId + "_" + UUID.randomUUID() + ".jpg";

        profile.setFaceImageUrl(imageUrl);
        profile.setFaceRegistered(true);
        workerProfileRepository.save(profile);

        log.info("人臉註冊成功(模擬): userId={}, imageUrl={}", userId, imageUrl);

        Map<String, Object> result = new HashMap<>();
        result.put("faceImageUrl", imageUrl);
        result.put("faceRegistered", true);
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> registerFaceBase64(Long userId, String base64Image) {
        if (base64Image == null || base64Image.isEmpty()) {
            throw new BusinessException(400, "請上傳人臉圖片");
        }

        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        try {
            // 解码 base64
            byte[] imageBytes = Base64.getDecoder().decode(base64Image);

            // 保存到 uploads/faces/ 目录
            String facesDir = uploadDir + "/faces/";
            Files.createDirectories(Paths.get(facesDir));

            String fileName = "w" + userId + "_" + UUID.randomUUID().toString().substring(0, 8) + ".jpg";
            Path destPath = Paths.get(facesDir + fileName);
            Files.write(destPath, imageBytes);

            String imageUrl = "/uploads/faces/" + fileName;

            profile.setFaceImageUrl(imageUrl);
            profile.setFaceRegistered(true);
            workerProfileRepository.save(profile);

            log.info("人臉註冊成功: userId={}, imageUrl={}, size={}bytes", userId, imageUrl, imageBytes.length);

            Map<String, Object> result = new HashMap<>();
            result.put("faceImageUrl", imageUrl);
            result.put("faceRegistered", true);
            return result;

        } catch (IOException e) {
            log.error("人臉圖片保存失敗: userId={}, error={}", userId, e.getMessage());
            throw new BusinessException(500, "人臉圖片保存失敗");
        }
    }

    @Override
    public Map<String, Object> verifyFace(Long userId, String liveBase64) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (!Boolean.TRUE.equals(profile.getFaceRegistered()) || profile.getFaceImageUrl() == null) {
            throw new BusinessException(400, "請先完成人臉登記");
        }

        // 获取注册图片的本地路径
        String uploadDirPath = uploadDir;
        String imageUrl = profile.getFaceImageUrl();
        // imageUrl 格式: /uploads/faces/xxx.jpg → ./uploads/faces/xxx.jpg
        String localPath = uploadDirPath + imageUrl.substring(imageUrl.indexOf("/faces"));

        File regFile = new File(localPath);
        if (!regFile.exists()) {
            log.error("人臉註冊圖片不存在: {}", localPath);
            throw new BusinessException(500, "人臉註冊圖片不存在，請重新登記");
        }

        // 调用 pHash 进行对比
        int score = faceVerificationService.verify(localPath, liveBase64);
        boolean matched = score >= verificationThreshold;

        log.info("人臉驗證: userId={}, score={}, matched={}", userId, score, matched);

        Map<String, Object> result = new HashMap<>();
        result.put("matched", matched);
        result.put("score", score);
        return result;
    }

    @Override
    public Page<SafetyDeduction> getDeductions(Long userId, int page, int size) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
        return safetyDeductionRepository.findByWorkerId(profile.getId(), PageRequest.of(page, size));
    }
}
