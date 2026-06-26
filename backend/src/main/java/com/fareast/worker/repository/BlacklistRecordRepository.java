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

    // 按姓名查找仍生效的黑名单记录（用于跨工人比对）
    List<BlacklistRecord> findByNameAndStatusTrue(String name);

    // 按工人注册证号查找仍生效的黑名单记录
    List<BlacklistRecord> findByWorkerRegistrationNumAndStatusTrue(String workerRegistrationNum);
}
