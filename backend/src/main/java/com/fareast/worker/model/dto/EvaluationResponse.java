package com.fareast.worker.model.dto;

import com.fareast.worker.model.entity.ContractorSafetyEvaluation;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvaluationResponse {
    private Long id;
    private Long siteId;
    private String siteName;
    private Long companyId;
    private String companyName;
    private String tradeOfWork;
    private String period;
    private Integer periodYear;
    private Integer periodQuarter;

    // 评分项（key=序号 Integer）
    private Map<Integer, Integer> scores;

    private Integer totalScore;
    private BigDecimal percentage;
    private String nonCompliantLevel;

    private String templateCode;
    private String status;
    private Long submittedBy;
    private String submittedByName;
    private LocalDateTime submittedAt;
    private Long assignedTo;
    private String assignedToName;
    private Long approvedBy;
    private String approvedByName;
    private LocalDateTime approvedAt;
    private String approvalComment;
    private LocalDateTime notifiedAt;

    private String evidenceAttachments;
    private String remarks;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static EvaluationResponse from(ContractorSafetyEvaluation e) {
        Map<Integer, Integer> scores = new LinkedHashMap<>();
        scores.put(1, e.getScore1());
        scores.put(2, e.getScore2());
        scores.put(3, e.getScore3());
        scores.put(4, e.getScore4());
        scores.put(5, e.getScore5());
        scores.put(6, e.getScore6());
        scores.put(7, e.getScore7());
        scores.put(8, e.getScore8());
        scores.put(9, e.getScore9());
        scores.put(10, e.getScore10());
        scores.put(11, e.getScore11());
        scores.put(12, e.getScore12());
        scores.put(13, e.getScore13());
        scores.put(14, e.getScore14());
        scores.put(15, e.getScore15());
        scores.put(16, e.getScore16());
        scores.put(17, e.getScore17());
        scores.put(18, e.getScore18());
        scores.put(19, e.getScore19());
        scores.put(20, e.getScore20());
        scores.put(21, e.getScore21());
        scores.put(22, e.getScore22());

        return EvaluationResponse.builder()
                .id(e.getId())
                .siteId(e.getSiteId())
                .companyId(e.getCompanyId())
                .tradeOfWork(e.getTradeOfWork())
                .period(e.getPeriod())
                .periodYear(e.getPeriodYear())
                .periodQuarter(e.getPeriodQuarter())
                .scores(scores)
                .totalScore(e.getTotalScore())
                .percentage(e.getPercentage())
                .nonCompliantLevel(e.getNonCompliantLevel())
                .templateCode(e.getTemplateCode())
                .status(e.getStatus())
                .submittedBy(e.getSubmittedBy())
                .submittedAt(e.getSubmittedAt())
                .assignedTo(e.getAssignedTo())
                .approvedBy(e.getApprovedBy())
                .approvedAt(e.getApprovedAt())
                .approvalComment(e.getApprovalComment())
                .notifiedAt(e.getNotifiedAt())
                .evidenceAttachments(e.getEvidenceAttachments())
                .remarks(e.getRemarks())
                .createdAt(e.getCreatedAt())
                .updatedAt(e.getUpdatedAt())
                .build();
    }
}
