package com.fareast.worker.model.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
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
@Table(name = "worker_profiles")
public class WorkerProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private Long userId;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "userId", referencedColumnName = "id", insertable = false, updatable = false)
    @JsonIgnore
    private User user;

    @Column
    private String chineseName;

    @Column
    private String englishName;

    @Column
    private String safetyCard;

    @Column
    private String workerRegistrationNum;

    @Column
    private String safetyCardAttachment;

    @Column
    private String workerRegCertAttachment;

    @Column(precision = 10, scale = 2)
    private BigDecimal dailyWage;

    @Column
    private String contractAttachment;

    @Column
    private Boolean faceRegistered;

    @Column
    private String faceImageUrl;

    @Column(unique = true)
    private String workerNumber;

    @Builder.Default
    @Column(nullable = false)
    private Boolean blacklisted = false;

    @Column
    private String blacklistReason;

    @Builder.Default
    @Column(nullable = false)
    private Boolean cardLocked = false;

    @Column
    private Long currentSiteId;

    @Column
    private Long currentCompanyId;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(nullable = false)
    private LocalDateTime updatedAt;
}
