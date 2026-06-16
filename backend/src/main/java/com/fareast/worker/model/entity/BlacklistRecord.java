package com.fareast.worker.model.entity;

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
@Table(name = "blacklist_records")
public class BlacklistRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long workerId;

    @Column(nullable = false)
    private String reason;

    @Column(nullable = false)
    private Long addedBy;

    @Column(nullable = false)
    private LocalDateTime addedAt;

    @Column
    private LocalDateTime removedAt;

    @Column
    private Long removedBy;
}
