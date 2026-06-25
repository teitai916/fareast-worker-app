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

    /*
     * 人脸识别功能已注释（App Store 合规要求）
    Map<String, Object> registerFace(Long userId, MultipartFile faceImage);
    Map<String, Object> registerFaceBase64(Long userId, String base64Image);
    Map<String, Object> verifyFace(Long userId, String liveBase64);
    */

    /**
     * Get paginated deduction records for a worker.
     */
    Page<SafetyDeduction> getDeductions(Long userId, int page, int size);
}
