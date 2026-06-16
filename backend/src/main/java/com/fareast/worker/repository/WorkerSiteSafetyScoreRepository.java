package com.fareast.worker.repository;

import com.fareast.worker.model.entity.WorkerSiteSafetyScore;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkerSiteSafetyScoreRepository extends JpaRepository<WorkerSiteSafetyScore, Long> {

    /// 查找工人在指定地盘的安全分记录
    Optional<WorkerSiteSafetyScore> findByWorkerIdAndSiteId(Long workerId, Long siteId);

    /// 查找工人在所有地盘的安全分记录
    List<WorkerSiteSafetyScore> findByWorkerId(Long workerId);

    /// 查找地盘下所有工人的安全分记录
    List<WorkerSiteSafetyScore> findBySiteId(Long siteId);

    /// 检查是否存在记录
    boolean existsByWorkerIdAndSiteId(Long workerId, Long siteId);
}
