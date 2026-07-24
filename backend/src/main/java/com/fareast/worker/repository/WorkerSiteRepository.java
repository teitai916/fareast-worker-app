package com.fareast.worker.repository;

import com.fareast.worker.model.entity.WorkerSite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkerSiteRepository extends JpaRepository<WorkerSite, Long> {
    List<WorkerSite> findByWorkerId(Long workerId);
    Optional<WorkerSite> findByWorkerIdAndSiteId(Long workerId, Long siteId);
    List<WorkerSite> findBySiteId(Long siteId);
    long countByWorkerId(Long workerId);
}
