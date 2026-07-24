package com.fareast.worker.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "deduction_items")
public class DeductionItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "category_name", nullable = false, length = 100)
    private String categoryName;

    @Column(name = "item_name", nullable = false, length = 200)
    private String itemName;

    @Column(nullable = false)
    private Integer points;

    @Column(name = "sort_order")
    private Integer sortOrder;
}
