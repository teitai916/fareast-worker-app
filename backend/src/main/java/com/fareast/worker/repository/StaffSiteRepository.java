package com.fareast.worker.repository;

import com.fareast.worker.model.entity.StaffSite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StaffSiteRepository extends JpaRepository<StaffSite, Long> {
    List<StaffSite> findByUserId(Long userId);
    Optional<StaffSite> findByUserIdAndSiteId(Long userId, Long siteId);
    Optional<StaffSite> findByUserIdAndIsCurrentTrue(Long userId);
    long countByUserId(Long userId);
}
