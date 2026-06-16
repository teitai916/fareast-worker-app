package com.fareast.worker.repository;

import com.fareast.worker.model.entity.SafetyDeduction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

@Repository
public interface SafetyDeductionRepository extends JpaRepository<SafetyDeduction, Long> {

    List<SafetyDeduction> findByWorkerId(Long workerId);

    Page<SafetyDeduction> findByWorkerId(Long workerId, Pageable pageable);

    @Query("SELECT COALESCE(SUM(s.points), 0) FROM SafetyDeduction s WHERE s.workerId = :workerId")
    Integer sumPointsByWorkerId(Long workerId);
}
