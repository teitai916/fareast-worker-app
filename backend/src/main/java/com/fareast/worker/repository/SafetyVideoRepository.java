package com.fareast.worker.repository;

import com.fareast.worker.model.entity.SafetyVideo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SafetyVideoRepository extends JpaRepository<SafetyVideo, Long> {
}
