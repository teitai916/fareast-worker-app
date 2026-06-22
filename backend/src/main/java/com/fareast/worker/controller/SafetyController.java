package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.WorkerVideoView;
import com.fareast.worker.repository.WorkerVideoViewRepository;
import com.fareast.worker.service.SafetyService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/safety")
public class SafetyController {

    @Autowired
    private SafetyService safetyService;

    @Autowired
    private WorkerVideoViewRepository workerVideoViewRepository;

    @GetMapping("/videos")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<List<SafetyVideo>> getVideos(
            @AuthenticationPrincipal String userId) {
        List<SafetyVideo> videos = safetyService.getAllVideos();
        Long uid = Long.valueOf(userId);
        for (SafetyVideo video : videos) {
            Optional<WorkerVideoView> view = workerVideoViewRepository
                    .findByWorkerIdAndVideoId(uid, video.getId());
            video.setCompleted(view.isPresent() && Boolean.TRUE.equals(view.get().getCompleted()));
        }
        return ApiResponse.success(videos);
    }

    @PostMapping("/video-watched")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<Void> videoWatched(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long videoId = Long.valueOf(requestBody.get("videoId").toString());
        Integer watchedDuration = Integer.valueOf(requestBody.get("watchedDuration").toString());
        safetyService.recordVideoWatched(Long.valueOf(userId), videoId, watchedDuration);
        return ApiResponse.success(null);
    }

    @GetMapping("/completion-status")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<Map<String, Object>> getCompletionStatus(
            @AuthenticationPrincipal String userId) {
        boolean checkInAllowed = safetyService.isCheckInAllowed(Long.valueOf(userId));
        Map<String, Object> result = new HashMap<>();
        result.put("checkInAllowed", checkInAllowed);
        return ApiResponse.success(result);
    }
}
