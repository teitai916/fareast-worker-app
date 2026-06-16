package com.fareast.worker.model.entity;

import com.fareast.worker.model.enums.AuditStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "site_change_requests")
public class SiteChangeRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long workerId;

    @Column(nullable = false)
    private Long fromSiteId;

    @Column(nullable = false)
    private Long toSiteId;

    // 目标工地所属公司ID（冗余字段，方便判头查询）
    @Column(nullable = false)
    private Long companyId;

    @Column(nullable = false)
    private String reason;

    // 每日薪酬
    @Column(precision = 10, scale = 2)
    private BigDecimal dailyWage;

    // 僱佣合约附件路径
    @Column
    private String contractAttachment;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AuditStatus status;

    @Column(nullable = false)
    private LocalDateTime requestedAt;

    @Column
    private LocalDateTime processedAt;

    @Column
    private Long processedBy;

    @Column
    private String rejectReason;
}
