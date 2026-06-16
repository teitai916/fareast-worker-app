package com.fareast.worker.repository;

import com.fareast.worker.model.entity.WorkerVideoView;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkerVideoViewRepository extends JpaRepository<WorkerVideoView, Long> {

    Optional<WorkerVideoView> findByWorkerIdAndVideoId(Long workerId, Long videoId);

    List<WorkerVideoView> findByWorkerId(Long workerId);

    int countByWorkerIdAndCompletedTrue(Long workerId);
}
