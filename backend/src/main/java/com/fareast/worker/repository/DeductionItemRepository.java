package com.fareast.worker.repository;

import com.fareast.worker.model.entity.DeductionItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DeductionItemRepository extends JpaRepository<DeductionItem, Long> {

    /** 按分类名查询，按 sort_order 排序 */
    List<DeductionItem> findByCategoryNameOrderBySortOrderAsc(String categoryName);

    /** 获取所有去重的分类名 */
    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT d.categoryName FROM DeductionItem d ORDER BY d.categoryName")
    List<String> findDistinctCategoryNames();

    /** 全量查询，按 sort_order 排序 */
    List<DeductionItem> findAllByOrderByCategoryNameAscSortOrderAsc();
}
