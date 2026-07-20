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

    // 21项评分(使用Map方便前端动态渲染)
    private Map<String, Integer> scores;

    private Integer totalScore;
    private BigDecimal percentage;
    private String nonCompliantLevel;

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
        Map<String, Integer> scores = new LinkedHashMap<>();
        scores.put("管理层安全态度", e.getScore1());
        scores.put("具備足夠能力的安全人員", e.getScore2());
        scores.put("提供安全訓練、指示及監督", e.getScore3());
        scores.put("地盤安全設施之提供及維持", e.getScore4());
        scores.put("合作性", e.getScore5());
        scores.put("提供予屬下員工及使用個人保護裝置", e.getScore6());
        scores.put("安全意外率", e.getScore7());
        scores.put("安全表現", e.getScore8());
        scores.put("提供適當安装方法/程序, 或專業分判施工方案", e.getScore9());
        scores.put("聘請安全督導員", e.getScore10());
        scores.put("起重機械/裝置證書", e.getScore11());
        scores.put("高空工作", e.getScore12());
        scores.put("個人防護裝備使用情況", e.getScore13());
        scores.put("施工/物料擺放位置整潔", e.getScore14());
        scores.put("依照施工方案進行工序", e.getScore15());
        scores.put("改善態度", e.getScore16());
        scores.put("參與早會及安全施工程序會議", e.getScore17());
        scores.put("提供合適的工具", e.getScore18());
        scores.put("合約安全守則", e.getScore19());
        scores.put("法例(包括工作守則)", e.getScore20());
        scores.put("工傷事故記錄", e.getScore21());
        scores.put("敦促改善通知書(部份II)/停工通知書 (發出日期)", e.getScore22());

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
