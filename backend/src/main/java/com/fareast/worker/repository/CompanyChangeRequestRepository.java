package com.fareast.worker.repository;

import com.fareast.worker.model.entity.CompanyChangeRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CompanyChangeRequestRepository extends JpaRepository<CompanyChangeRequest, Long> {
}
