package com.fareast.worker.service;

import com.fareast.worker.model.entity.Attendance;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public interface InternalAttendanceService {

    /**
     * 内部人员打卡签到/签退
     */
    Attendance checkIn(Long userId, Long siteId, String checkInType);

    /**
     * 获取今日考勤记录
     */
    Map<String, Object> getDailyRecord(Long userId, LocalDate date);

    /**
     * 获取月度考勤天数
     */
    List<Integer> getMonthlyDays(Long userId, int year, int month);
}
