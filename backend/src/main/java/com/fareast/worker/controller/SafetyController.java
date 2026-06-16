package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.service.SafetyService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/safety")
public class SafetyController {

    @Autowired
    private SafetyService safetyService;

    @GetMapping("/videos")
    public ApiResponse<List<SafetyVideo>> getVideos() {
        List<SafetyVideo> videos = safetyService.getAllVideos();
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
}
