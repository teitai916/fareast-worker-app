package com.fareast.worker.repository;

import com.fareast.worker.model.entity.EvaluationScoreItem;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface EvaluationScoreItemRepository extends JpaRepository<EvaluationScoreItem, Long> {
    List<EvaluationScoreItem> findByTemplateIdOrderByScoreIndexAsc(Long templateId);
}
