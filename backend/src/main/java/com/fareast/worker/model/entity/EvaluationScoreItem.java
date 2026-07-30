package com.fareast.worker.model.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "evaluation_score_items")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EvaluationScoreItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "template_id", nullable = false)
    private Long templateId;

    @Column(name = "score_index", nullable = false)
    private Integer scoreIndex;

    @Column(nullable = false, length = 100)
    private String category;

    @Column(name = "name_zh", nullable = false, length = 200)
    private String nameZh;

    @Column(name = "sort_order")
    private Integer sortOrder;

    @Column(name = "guide_tier_1", length = 200)
    private String guideTier1;

    @Column(name = "guide_tier_1_range", length = 20)
    private String guideTier1Range;

    @Column(name = "guide_tier_2", length = 200)
    private String guideTier2;

    @Column(name = "guide_tier_2_range", length = 20)
    private String guideTier2Range;

    @Column(name = "guide_tier_3", length = 200)
    private String guideTier3;

    @Column(name = "guide_tier_3_range", length = 20)
    private String guideTier3Range;

    @Column(name = "guide_tier_4", length = 200)
    private String guideTier4;

    @Column(name = "guide_tier_4_range", length = 20)
    private String guideTier4Range;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
