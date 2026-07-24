package com.fareast.worker.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "worker_sites", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"worker_id", "site_id"})
})
public class WorkerSite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "worker_id", nullable = false)
    private Long workerId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "daily_wage", precision = 10, scale = 2)
    private BigDecimal dailyWage;

    @Column(name = "contract_attachment", length = 500)
    private String contractAttachment;

    @CreationTimestamp
    @Column(name = "joined_at")
    private LocalDateTime joinedAt;
}
