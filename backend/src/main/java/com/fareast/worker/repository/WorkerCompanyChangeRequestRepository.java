package com.fareast.worker.repository;

import com.fareast.worker.model.entity.WorkerCompanyChangeRequest;
import com.fareast.worker.model.enums.AuditStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface WorkerCompanyChangeRequestRepository extends JpaRepository<WorkerCompanyChangeRequest, Long> {

    List<WorkerCompanyChangeRequest> findByWorkerIdOrderByRequestedAtDesc(Long workerId);

    List<WorkerCompanyChangeRequest> findByToCompanyIdAndStatusOrderByRequestedAtDesc(Long toCompanyId, AuditStatus status);

    List<WorkerCompanyChangeRequest> findByToCompanyIdOrderByRequestedAtDesc(Long toCompanyId);

    long countByToCompanyIdAndStatus(Long toCompanyId, AuditStatus status);

    Optional<WorkerCompanyChangeRequest> findByWorkerIdAndStatus(Long workerId, AuditStatus status);

    List<WorkerCompanyChangeRequest> findByStatus(AuditStatus status);
}
