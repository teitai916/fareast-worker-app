package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.StaffProfile;
import com.fareast.worker.model.entity.StaffSite;
import com.fareast.worker.model.enums.CheckInType;
import com.fareast.worker.repository.AttendanceRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.StaffProfileRepository;
import com.fareast.worker.repository.StaffSiteRepository;
import com.fareast.worker.service.InternalAttendanceService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
public class InternalAttendanceServiceImpl implements InternalAttendanceService {

    @Autowired
    private StaffProfileRepository staffProfileRepository;

    @Autowired
    private StaffSiteRepository staffSiteRepository;

    @Autowired
    private AttendanceRepository attendanceRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Override
    @Transactional
    public Attendance checkIn(Long userId, Long siteId, String checkInType) {
        // 1. 确保 StaffProfile 存在（自动创建）
        StaffProfile profile = staffProfileRepository.findByUserId(userId)
                .orElseGet(() -> {
                    StaffProfile newProfile = StaffProfile.builder()
                            .userId(userId)
                            .currentSiteId(siteId)
                            .build();
                    StaffProfile saved = staffProfileRepository.save(newProfile);
                    log.info("自动创建StaffProfile: userId={}, profileId={}", userId, saved.getId());
                    return saved;
                });

        // 2. 检查是否有该地盘的权限
        Optional<StaffSite> staffSite = staffSiteRepository.findByUserIdAndSiteId(userId, siteId);
        if (staffSite.isEmpty()) {
            throw new BusinessException(403, "您未加入此地盤，無法打卡");
        }

        // 3. 更新当前站点
        profile.setCurrentSiteId(siteId);
        staffProfileRepository.save(profile);

        LocalDate today = LocalDate.now();
        LocalDateTime now = LocalDateTime.now();

        // 4. 查询今日所有打卡记录（支持多地盘打卡）
        List<Attendance> todayRecords = attendanceRepository.findByWorkerIdAndDateBetween(
                profile.getId(), today, today);

        // 查找同一地盘是否有未签退的记录（同一地盘再次打卡 = 签退）
        Optional<Attendance> sameSiteIncomplete = todayRecords.stream()
                .filter(r -> r.getSiteId() != null && r.getSiteId().equals(siteId) && r.getCheckOutTime() == null)
                .findFirst();

        if (sameSiteIncomplete.isPresent()) {
            // 同一地盘再次打卡 → 签退
            Attendance incomplete = sameSiteIncomplete.get();
            incomplete.setCheckOutTime(now);
            attendanceRepository.save(incomplete);
            log.info("內部人員離場打卡成功(同地盤): staffProfileId={}, siteId={}", profile.getId(), siteId);
            return incomplete;
        }

        // 查找其他地盘未签退的记录 → 自动签退
        Optional<Attendance> otherSiteIncomplete = todayRecords.stream()
                .filter(r -> r.getCheckOutTime() == null)
                .findFirst();

        if (otherSiteIncomplete.isPresent()) {
            // 自动签退上一个地盘
            Attendance prev = otherSiteIncomplete.get();
            prev.setCheckOutTime(now);
            attendanceRepository.save(prev);
            log.info("自動簽退上一個地盤: staffProfileId={}, prevSiteId={}, newSiteId={}",
                    profile.getId(), prev.getSiteId(), siteId);
        }

        // 5. 创建新地盘签到记录
        CheckInType type;
        try {
            type = CheckInType.valueOf(checkInType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BusinessException(400, "無效的打卡類型: " + checkInType);
        }

        Attendance attendance = Attendance.builder()
                .workerId(profile.getId())
                .siteId(siteId)
                .checkInTime(now)
                .checkInType(type)
                .date(today)
                .build();

        attendance = attendanceRepository.save(attendance);
        log.info("內部人員入場打卡成功: staffProfileId={}, siteId={}", profile.getId(), siteId);
        return attendance;
    }

    @Override
    public Map<String, Object> getDailyRecord(Long userId, LocalDate date) {
        StaffProfile profile = staffProfileRepository.findByUserId(userId).orElse(null);
        if (profile == null) return null;

        List<Attendance> records = attendanceRepository.findByWorkerIdAndDateBetween(
                profile.getId(), date, date);
        if (records.isEmpty()) return null;

        // 按签到时间排序
        records.sort(Comparator.comparing(Attendance::getCheckInTime));

        long totalMinutes = 0;
        List<Map<String, Object>> recordList = new ArrayList<>();
        for (Attendance r : records) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", r.getId());
            m.put("checkInTime", r.getCheckInTime() != null ? r.getCheckInTime().toString() : null);
            m.put("checkOutTime", r.getCheckOutTime() != null ? r.getCheckOutTime().toString() : null);
            m.put("siteId", r.getSiteId());

            // 地盘名
            if (r.getSiteId() != null) {
                siteRepository.findById(r.getSiteId()).ifPresent(site ->
                        m.put("siteName", site.getName()));
            }

            // 时长
            if (r.getCheckInTime() != null && r.getCheckOutTime() != null) {
                long minutes = java.time.Duration.between(r.getCheckInTime(), r.getCheckOutTime()).toMinutes();
                m.put("durationMinutes", minutes);
                m.put("duration", formatDuration(minutes));
                totalMinutes += minutes;
            } else {
                m.put("durationMinutes", null);
                m.put("duration", "進行中");
            }

            recordList.add(m);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("date", date.toString());
        result.put("records", recordList);
        result.put("recordCount", recordList.size());
        result.put("totalDuration", formatDuration(totalMinutes));
        result.put("totalDurationMinutes", totalMinutes);
        return result;
    }

    private String formatDuration(long minutes) {
        long h = minutes / 60;
        long m = minutes % 60;
        if (h > 0) return h + "小時" + (m > 0 ? m + "分" : "");
        return m + "分";
    }

    @Override
    public List<Integer> getMonthlyDays(Long userId, int year, int month) {
        StaffProfile profile = staffProfileRepository.findByUserId(userId).orElse(null);
        if (profile == null) return Collections.emptyList();

        LocalDate start = LocalDate.of(year, month, 1);
        LocalDate end = start.plusMonths(1).minusDays(1);

        return attendanceRepository.findByWorkerIdAndDateBetween(profile.getId(), start, end).stream()
                .map(r -> r.getDate().getDayOfMonth())
                .distinct()
                .sorted()
                .collect(java.util.stream.Collectors.toList());
    }
}
