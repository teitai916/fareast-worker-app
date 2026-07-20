package com.fareast.worker.model.dto;

import lombok.Data;

@Data
public class CreateEvaluationRequest {
    private Long siteId;
    private Long companyId;
    private String tradeOfWork;
    private String period;           // QUARTERLY / ANNUAL
    private Integer periodYear;
    private Integer periodQuarter;

    // 21项评分
    private Integer score1;
    private Integer score2;
    private Integer score3;
    private Integer score4;
    private Integer score5;
    private Integer score6;
    private Integer score7;
    private Integer score8;
    private Integer score9;
    private Integer score10;
    private Integer score11;
    private Integer score12;
    private Integer score13;
    private Integer score14;
    private Integer score15;
    private Integer score16;
    private Integer score17;
    private Integer score18;
    private Integer score19;
    private Integer score20;
    private Integer score21;
    private Integer score22;

    private String evidenceAttachments;  // JSON数组
    private String remarks;
}
