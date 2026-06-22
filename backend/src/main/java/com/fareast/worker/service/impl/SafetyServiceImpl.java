package com.fareast.worker.service.impl;

import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.entity.WorkerVideoView;
import com.fareast.worker.repository.SafetyVideoRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.WorkerVideoViewRepository;
import com.fareast.worker.service.SafetyService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
public class SafetyServiceImpl implements SafetyService {

    @Autowired
    private SafetyVideoRepository safetyVideoRepository;

    @Autowired
    private WorkerVideoViewRepository workerVideoViewRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Override
    public List<SafetyVideo> getAllVideos() {
        return safetyVideoRepository.findAll();
    }

    @Override
    @Transactional
    public void recordVideoWatched(Long workerId, Long videoId, Integer watchedDuration) {
        // Find or create worker profile to validate worker exists
        WorkerProfile profile = workerProfileRepository.findByUserId(workerId)
                .orElse(null);

        // Check if video exists
        SafetyVideo video = safetyVideoRepository.findById(videoId)
                .orElse(null);

        // Record the view
        Optional<WorkerVideoView> existingView = workerVideoViewRepository.findByWorkerIdAndVideoId(workerId, videoId);

        WorkerVideoView view;
        if (existingView.isPresent()) {
            view = existingView.get();
            view.setWatchedDuration(watchedDuration);
            view.setViewedAt(LocalDateTime.now());
            if (video != null && watchedDuration >= video.getDuration()) {
                view.setCompleted(true);
            }
        } else {
            view = WorkerVideoView.builder()
                    .workerId(workerId)
                    .videoId(videoId)
                    .watchedDuration(watchedDuration)
                    .viewedAt(LocalDateTime.now())
                    .completed(video != null && watchedDuration >= video.getDuration())
                    .build();
        }

        workerVideoViewRepository.save(view);
        log.info("影片觀看記錄已保存: workerId={}, videoId={}, watchedDuration={}", workerId, videoId, watchedDuration);
    }

    @Override
    @Transactional
    public void resetMandatoryVideos(Long workerId) {
        List<SafetyVideo> mandatoryVideos = safetyVideoRepository.findAll().stream()
                .filter(SafetyVideo::getMandatory)
                .collect(java.util.stream.Collectors.toList());

        for (SafetyVideo video : mandatoryVideos) {
            Optional<WorkerVideoView> existingView = workerVideoViewRepository
                    .findByWorkerIdAndVideoId(workerId, video.getId());
            if (existingView.isPresent()) {
                WorkerVideoView view = existingView.get();
                view.setCompleted(false);
                view.setWatchedDuration(0);
                workerVideoViewRepository.save(view);
                log.info("必修影片完成狀態已重置: workerId={}, videoId={}", workerId, video.getId());
            }
        }
        log.info("工人必修影片完成狀態已全部重置: workerId={}, 共{}部影片", workerId, mandatoryVideos.size());
    }

    @Override
    public boolean isCheckInAllowed(Long userId) {
        List<SafetyVideo> mandatoryVideos = safetyVideoRepository.findAll().stream()
                .filter(SafetyVideo::getMandatory)
                .collect(java.util.stream.Collectors.toList());

        if (mandatoryVideos.isEmpty()) {
            return true;
        }

        int completedCount = workerVideoViewRepository.countByWorkerIdAndCompletedTrue(userId);
        return completedCount >= mandatoryVideos.size();
    }
}
