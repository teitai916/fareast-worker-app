package com.fareast.worker.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WorkerRegisterRequest {

    private String phone;

    private String name;

    private String chineseName;

    private String englishName;

    private String safetyCard;

    private String workerRegistrationNum;

    private BigDecimal dailyWage;

    private Long siteId;
}
