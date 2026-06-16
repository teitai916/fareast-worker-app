package com.fareast.worker.service;

import com.fareast.worker.model.entity.SafetyVideo;

import java.util.List;

public interface SafetyService {

    List<SafetyVideo> getAllVideos();

    void recordVideoWatched(Long workerId, Long videoId, Integer watchedDuration);
}
