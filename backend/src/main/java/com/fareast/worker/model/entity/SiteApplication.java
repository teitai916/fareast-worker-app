package com.fareast.worker.model.entity;

import com.fareast.worker.model.enums.AuditStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "site_applications")
public class SiteApplication {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long workerId;          // user_id of the worker

    @Column(nullable = false)
    private Long siteId;

    @Column(nullable = false)
    private Long companyId;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    @Column(nullable = false)
    private AuditStatus status = AuditStatus.PENDING;

    private String remark;          // worker's self-introduction / note

    private Long reviewedBy;        // manager who approved/rejected

    private LocalDateTime reviewedAt;

    private String reviewRemark;    // manager's comment

    @Column
    private java.math.BigDecimal dailyWage;

    @Column
    private String contractAttachment;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
