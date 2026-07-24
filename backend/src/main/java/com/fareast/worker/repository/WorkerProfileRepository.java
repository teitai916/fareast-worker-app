package com.fareast.worker.repository;

import com.fareast.worker.model.entity.WorkerProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkerProfileRepository extends JpaRepository<WorkerProfile, Long> {

    Optional<WorkerProfile> findByUserId(Long userId);

    Optional<WorkerProfile> findByWorkerNumber(String workerNumber);

    List<WorkerProfile> findByBlacklistedTrue();

    List<WorkerProfile> findByCardLockedTrue();

    List<WorkerProfile> findByCompanyId(Long companyId);
}
