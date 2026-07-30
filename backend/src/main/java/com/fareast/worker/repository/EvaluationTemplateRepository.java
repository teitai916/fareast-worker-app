package com.fareast.worker.repository;

import com.fareast.worker.model.entity.EvaluationTemplate;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface EvaluationTemplateRepository extends JpaRepository<EvaluationTemplate, Long> {
    Optional<EvaluationTemplate> findByCode(String code);
}
