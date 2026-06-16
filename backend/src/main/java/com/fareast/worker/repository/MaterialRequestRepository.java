package com.fareast.worker.repository;

import com.fareast.worker.model.entity.MaterialRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MaterialRequestRepository extends JpaRepository<MaterialRequest, Long> {

    List<MaterialRequest> findByWorkerId(Long workerId);

    List<MaterialRequest> findBySiteId(Long siteId);

    List<MaterialRequest> findByStatus(String status);
}
