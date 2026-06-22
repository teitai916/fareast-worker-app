package com.fareast.worker.service;

import com.fareast.worker.model.entity.SafetyVideo;

import java.util.List;

public interface SafetyService {

    List<SafetyVideo> getAllVideos();

    void recordVideoWatched(Long workerId, Long videoId, Integer watchedDuration);

    /**
     * 重置工人的必修安全影片完成狀態
     * 在更換地盤或更換公司後調用，要求工人重新觀看
     */
    void resetMandatoryVideos(Long workerId);

    /**
     * 檢查工人是否已完成所有必修安全影片
     * @return true = 全部完成，可以打卡
     */
    boolean isCheckInAllowed(Long userId);
}
