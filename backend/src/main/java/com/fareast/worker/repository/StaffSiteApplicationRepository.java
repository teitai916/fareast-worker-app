package com.fareast.worker.repository;

import com.fareast.worker.model.entity.StaffSiteApplication;
import com.fareast.worker.model.enums.AuditStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StaffSiteApplicationRepository extends JpaRepository<StaffSiteApplication, Long> {
    List<StaffSiteApplication> findByUserId(Long userId);
    Optional<StaffSiteApplication> findByUserIdAndSiteIdAndStatus(Long userId, Long siteId, AuditStatus status);
    List<StaffSiteApplication> findByUserIdAndStatus(Long userId, AuditStatus status);
    boolean existsByUserIdAndSiteIdAndStatus(Long userId, Long siteId, AuditStatus status);
    List<StaffSiteApplication> findByStatus(AuditStatus status);
}
