package com.fareast.worker.service;

import com.fareast.worker.model.entity.Attendance;
import org.springframework.data.domain.Page;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public interface AttendanceService {

    /**
     * Worker check-in / check-out.
     * - No record today → create check-in record
     * - Record exists with null checkOutTime → update checkOutTime (check-out)
     * - Record exists with non-null checkOutTime → throws BusinessException
     *
     * @throws com.fareast.worker.exception.BusinessException if safety videos not completed
     */
    Attendance checkIn(Long userId, Double latitude, Double longitude, String checkInType, Long siteId);

    /**
     * Get paginated attendance records for a worker.
     */
    Page<Attendance> getRecords(Long userId, int page, int size);

    /**
     * Get all attendance records for a specific site on a given date.
     */
    List<Attendance> getRecordsBySite(Long siteId, LocalDate date);

    /**
     * Get a single attendance record for a worker on a specific date.
     * Returns a Map with: checkInTime, checkOutTime, siteName, checkInType, locationAddress.
     */
    Map<String, Object> getDailyRecord(Long userId, LocalDate date);

    /**
     * Get day numbers (1-31) that have attendance records for a worker in a given month.
     */
    List<Integer> getMonthlyDays(Long userId, int year, int month);
}
