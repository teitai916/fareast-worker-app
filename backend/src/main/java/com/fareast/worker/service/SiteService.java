package com.fareast.worker.service;

import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SiteChangeRequest;
import org.springframework.data.domain.Page;

import java.util.List;

public interface SiteService {

    /**
     * Get all available sites for workers to apply.
     */
    List<Site> getAllSites();

    /**
     * Get the site the worker is currently assigned to.
     */
    Site getCurrentSite(Long userId);

    /**
     * Get detailed info about a specific site.
     */
    Site getSiteById(Long siteId);

    /**
     * Request to change the worker's assigned site.
     */
    void requestSiteChange(Long userId, Long targetSiteId, String reason,
                          java.math.BigDecimal dailyWage, String contractAttachment);

    /**
     * Cancel a pending site change request for the worker.
     */
    void cancelSiteChange(Long userId);

    /**
     * Review a site change request (approve or reject).
     */
    void reviewChangeRequest(Long reviewerId, Long requestId, boolean approved, String reviewRemark);

    /**
     * Get paginated change history for the worker.
     */
    Page<SiteChangeRequest> getChangeHistory(Long userId, int page, int size);
}
