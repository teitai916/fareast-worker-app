package com.fareast.worker.repository;

import com.fareast.worker.model.entity.Attendance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    List<Attendance> findByWorkerIdAndDateBetween(Long workerId, LocalDate start, LocalDate end);

    Optional<Attendance> findByWorkerIdAndDate(Long workerId, LocalDate date);

    List<Attendance> findBySiteIdAndDate(Long siteId, LocalDate date);

    org.springframework.data.domain.Page<Attendance> findByWorkerId(Long workerId, org.springframework.data.domain.Pageable pageable);
}
