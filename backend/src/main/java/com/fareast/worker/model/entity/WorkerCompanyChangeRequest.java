package com.fareast.worker.model.entity;

import com.fareast.worker.model.enums.AuditStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "worker_company_change_requests")
public class WorkerCompanyChangeRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long workerId;

    @Column(nullable = false)
    private Long fromCompanyId;

    @Column(nullable = false)
    private Long toCompanyId;

    @Column(nullable = true)
    private String reason;

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

    @Column
    private java.math.BigDecimal dailySalary;

    @Column
    private String contractAttachment;

    @Column
    private String contractAttachmentName;
}
