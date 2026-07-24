package com.fareast.worker.repository;

import com.fareast.worker.model.entity.SiteApplication;
import com.fareast.worker.model.enums.AuditStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SiteApplicationRepository extends JpaRepository<SiteApplication, Long> {

    List<SiteApplication> findByWorkerId(Long workerId);

    Optional<SiteApplication> findByWorkerIdAndSiteId(Long workerId, Long siteId);

    List<SiteApplication> findByWorkerIdAndStatus(Long workerId, AuditStatus status);

    List<SiteApplication> findBySiteIdAndStatus(Long siteId, AuditStatus status);

    boolean existsByWorkerIdAndSiteIdAndStatusIn(Long workerId, Long siteId, List<AuditStatus> statuses);

    boolean existsByWorkerIdAndSiteIdAndStatus(Long workerId, Long siteId, AuditStatus status);

    List<SiteApplication> findByCompanyIdOrderByCreatedAtDesc(Long companyId);

    long countByCompanyIdAndStatus(Long companyId, AuditStatus status);
}
