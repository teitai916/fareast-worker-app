package com.fareast.worker.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "contractor_safety_evaluations")
public class ContractorSafetyEvaluation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(name = "trade_of_work", length = 100)
    private String tradeOfWork;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String period = "QUARTERLY";

    @Column(name = "period_year", nullable = false)
    private Integer periodYear;

    @Column(name = "period_quarter")
    private Integer periodQuarter;

    @Column(name = "template_code", length = 50)
    @Builder.Default
    private String templateCode = "SAFETY_2025";

    // 22项评分
    @Column(name = "score_1") private Integer score1;
    @Column(name = "score_2") private Integer score2;
    @Column(name = "score_3") private Integer score3;
    @Column(name = "score_4") private Integer score4;
    @Column(name = "score_5") private Integer score5;
    @Column(name = "score_6") private Integer score6;
    @Column(name = "score_7") private Integer score7;
    @Column(name = "score_8") private Integer score8;
    @Column(name = "score_9") private Integer score9;
    @Column(name = "score_10") private Integer score10;
    @Column(name = "score_11") private Integer score11;
    @Column(name = "score_12") private Integer score12;
    @Column(name = "score_13") private Integer score13;
    @Column(name = "score_14") private Integer score14;
    @Column(name = "score_15") private Integer score15;
    @Column(name = "score_16") private Integer score16;
    @Column(name = "score_17") private Integer score17;
    @Column(name = "score_18") private Integer score18;
    @Column(name = "score_19") private Integer score19;
    @Column(name = "score_20") private Integer score20;
    @Column(name = "score_21") private Integer score21;
    @Column(name = "score_22") private Integer score22;

    @Column(name = "total_score")
    private Integer totalScore;

    @Column(precision = 5, scale = 2)
    private BigDecimal percentage;

    @Column(name = "non_compliant_level", length = 20)
    @Builder.Default
    private String nonCompliantLevel = "NONE";

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "submitted_by")
    private Long submittedBy;

    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;

    @Column(name = "assigned_to")
    private Long assignedTo;

    @Column(name = "approved_by")
    private Long approvedBy;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(name = "approval_comment", columnDefinition = "TEXT")
    private String approvalComment;

    @Column(name = "notified_at")
    private LocalDateTime notifiedAt;

    @Column(name = "evidence_attachments", columnDefinition = "TEXT")
    private String evidenceAttachments;

    @Column(columnDefinition = "TEXT")
    private String remarks;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    // ===== 业务方法 =====

    /** 计算总分和百分比 */
    public void calculateScore() {
        int sum = 0;
        Integer[] scores = {score1, score2, score3, score4, score5, score6, score7, score8,
                score9, score10, score11, score12, score13, score14, score15, score16,
                score17, score18, score19, score20, score21, score22};
        for (Integer s : scores) {
            if (s != null) sum += s;
        }
        this.totalScore = sum;
        this.percentage = BigDecimal.valueOf(sum)
                .divide(BigDecimal.valueOf(220), 4, java.math.RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100));

        // 等級評定：低於80% → WARNING；SEVERE 由 Service 根據歷史判定
        if (this.percentage.compareTo(new BigDecimal("80")) < 0) {
            this.nonCompliantLevel = "WARNING";
        } else {
            this.nonCompliantLevel = "NONE";
        }
    }

    /** 判定是否升级为 SEVERE（需要上一季度百分比） */
    public void checkSevere(BigDecimal prevQuarterPercentage) {
        if (this.percentage.compareTo(new BigDecimal("60")) < 0) {
            // 當季低於60%
            this.nonCompliantLevel = "SEVERE";
        } else if (this.percentage.compareTo(new BigDecimal("80")) < 0
                && prevQuarterPercentage != null
                && prevQuarterPercentage.compareTo(new BigDecimal("80")) < 0) {
            // 年度連續兩季低於80%
            this.nonCompliantLevel = "SEVERE";
        }
    }
}
