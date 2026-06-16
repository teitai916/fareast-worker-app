package com.fareast.worker.repository;

import com.fareast.worker.model.entity.SiteChangeRequest;
import com.fareast.worker.model.enums.AuditStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SiteChangeRequestRepository extends JpaRepository<SiteChangeRequest, Long> {

    List<SiteChangeRequest> findByWorkerId(Long workerId);

    Page<SiteChangeRequest> findByWorkerId(Long workerId, Pageable pageable);

    List<SiteChangeRequest> findByToSiteId(Long siteId);

    List<SiteChangeRequest> findByCompanyIdAndStatusOrderByRequestedAtDesc(
            Long companyId, AuditStatus status);

    List<SiteChangeRequest> findByCompanyIdOrderByRequestedAtDesc(Long companyId);

    long countByCompanyIdAndStatus(Long companyId, AuditStatus status);
}
