package com.fareast.worker.repository;

import com.fareast.worker.model.entity.ContractorSafetyEvaluation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ContractorSafetyEvaluationRepository extends JpaRepository<ContractorSafetyEvaluation, Long> {

    /** 按归属地盘查询 */
    List<ContractorSafetyEvaluation> findBySiteIdOrderByCreatedAtDesc(Long siteId);

    /** 按被评分公司查询 */
    List<ContractorSafetyEvaluation> findByCompanyIdOrderByCreatedAtDesc(Long companyId);

    /** 按创建人查询 */
    List<ContractorSafetyEvaluation> findBySubmittedByOrderByCreatedAtDesc(Long submittedBy);

    /** 按审批人查询 */
    List<ContractorSafetyEvaluation> findByAssignedToOrderByCreatedAtDesc(Long assignedTo);

    /** 按审核状态查询 */
    List<ContractorSafetyEvaluation> findByStatusOrderByCreatedAtDesc(String status);

    /** 按地盘和状态查询 */
    List<ContractorSafetyEvaluation> findBySiteIdAndStatusOrderByCreatedAtDesc(Long siteId, String status);

    /** 查询某公司某年某季度的评分（防止重复） */
    @Query("SELECT e FROM ContractorSafetyEvaluation e WHERE e.companyId = :companyId " +
            "AND e.siteId = :siteId AND e.periodYear = :year AND e.periodQuarter = :quarter")
    List<ContractorSafetyEvaluation> findByCompanyAndSiteAndPeriod(
            @Param("companyId") Long companyId,
            @Param("siteId") Long siteId,
            @Param("year") Integer year,
            @Param("quarter") Integer quarter);

    /** 不合格列表 */
    List<ContractorSafetyEvaluation> findByNonCompliantLevelNotAndStatusOrderByCreatedAtDesc(
            String nonCompliantLevel, String status);

    /** 指定地盘列表中待审核的评分 */
    @Query("SELECT e FROM ContractorSafetyEvaluation e WHERE e.siteId IN :siteIds AND e.status = 'SUBMITTED' ORDER BY e.createdAt DESC")
    List<ContractorSafetyEvaluation> findPendingBySiteIds(@Param("siteIds") List<Long> siteIds);
}
