package com.fareast.worker.repository;

import com.fareast.worker.model.entity.BlacklistRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BlacklistRecordRepository extends JpaRepository<BlacklistRecord, Long> {

    List<BlacklistRecord> findByWorkerIdAndRemovedAtIsNull(Long workerId);

    Optional<BlacklistRecord> findByWorkerId(Long workerId);
}
