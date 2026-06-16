package com.fareast.worker.service;

import com.fareast.worker.model.dto.WorkerRegisterRequest;
import com.fareast.worker.model.entity.SafetyDeduction;
import com.fareast.worker.model.entity.WorkerProfile;
import org.springframework.data.domain.Page;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

public interface WorkerService {

    /**
     * Get the worker profile for the given user.
     */
    WorkerProfile getProfile(Long userId);

    /**
     * Register a new worker.
     */
    Map<String, Object> registerWorker(WorkerRegisterRequest request);

    /**
     * Register/upload a face image for the worker.
     */
    Map<String, Object> registerFace(Long userId, MultipartFile faceImage);

    /**
     * Register face using base64 encoded image (for web/mobile).
     */
    Map<String, Object> registerFaceBase64(Long userId, String base64Image);

    /**
     * 验证打卡时拍摄的人脸图片是否与注册时一致
     * @param userId 用户 ID
     * @param liveBase64 打卡时拍摄的 base64 图片
     * @return {matched: bool, score: int}
     */
    Map<String, Object> verifyFace(Long userId, String liveBase64);

    /**
     * Get paginated deduction records for a worker.
     */
    Page<SafetyDeduction> getDeductions(Long userId, int page, int size);
}
