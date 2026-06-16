package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.enums.CheckInType;
import com.fareast.worker.repository.AttendanceRepository;
import com.fareast.worker.repository.SafetyVideoRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.WorkerVideoViewRepository;
import com.fareast.worker.service.AttendanceService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
public class AttendanceServiceImpl implements AttendanceService {

    @Autowired
    private AttendanceRepository attendanceRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private SafetyVideoRepository safetyVideoRepository;

    @Autowired
    private WorkerVideoViewRepository workerVideoViewRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Value("${checkin.max-distance:300}")
    private double maxDistance; // 打卡最大允许距离（米）

    @Override
    @Transactional
    public Attendance checkIn(Long userId, Double latitude, Double longitude, String checkInType, Long siteId) {
        // Find worker profile
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不完整，請先完成註冊"));

        // Check if worker is blacklisted
        if (Boolean.TRUE.equals(profile.getBlacklisted())) {
            throw new BusinessException(403, "帳號已被列入黑名單，無法打卡");
        }

        // Check if card is locked
        if (Boolean.TRUE.equals(profile.getCardLocked())) {
            throw new BusinessException(403, "工卡已被鎖定，請聯絡管理員");
        }

        // Check face registration
        if (!Boolean.TRUE.equals(profile.getFaceRegistered())) {
            throw new BusinessException(400, "請先完成人臉登記");
        }

        // Check mandatory safety videos
        List<SafetyVideo> mandatoryVideos = safetyVideoRepository.findAll().stream()
                .filter(SafetyVideo::getMandatory)
                .collect(Collectors.toList());

        if (!mandatoryVideos.isEmpty()) {
            int completedCount = workerVideoViewRepository.countByWorkerIdAndCompletedTrue(profile.getId());
            if (completedCount < mandatoryVideos.size()) {
                log.warn("工人未完成安全培訓: userId={}, completed={}/{}",
                        userId, completedCount, mandatoryVideos.size());
                throw new BusinessException(400, "請先完成安全培訓影片");
            }
        }

        LocalDate today = LocalDate.now();

        // 地理围栏校验：检查工人是否在所在地盘 300 米范围内
        log.info("打卡請求: workerId={}, siteId={}, lat={}, lng={}",
                profile.getId(), siteId, latitude, longitude);
        if (latitude == null || longitude == null) {
            throw new BusinessException(400, "無法獲取定位資訊，請開啟 GPS");
        }
        Site site = siteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException(404, "地盤資訊不存在"));
        if (site.getLatitude() == null || site.getLongitude() == null) {
            log.warn("地盤 {} 經緯度未設定，跳過地理圍欄檢查", siteId);
        } else {
            double distance = calculateDistance(
                    latitude, longitude,
                    site.getLatitude(), site.getLongitude());

            // 无论是否通過均记录完整坐标
            log.info("地理圍欄結果: workerId={}, siteId={}, distance={}m, max={}m, workerLoc=[{},{}], siteLoc=[{},{}]",
                    profile.getId(), siteId, Math.round(distance), Math.round(maxDistance),
                    latitude, longitude, site.getLatitude(), site.getLongitude());

            if (distance > maxDistance) {
                log.warn("打卡位置距地盤過遠: workerId={}, siteId={}, distance={}m, max={}m",
                        profile.getId(), siteId, Math.round(distance), Math.round(maxDistance));
                throw new BusinessException(400,
                        "您不在打卡範圍內（距離地盤約 " + Math.round(distance) + " 米，最大允許 " + Math.round(maxDistance) + " 米）");
            }
        }

        // Check if already has a record today
        Optional<Attendance> existingOpt = attendanceRepository.findByWorkerIdAndDate(profile.getId(), today);

        if (existingOpt.isPresent()) {
            Attendance existing = existingOpt.get();
            // If checkOutTime is null → this is a CHECK-OUT
            if (existing.getCheckOutTime() == null) {

                existing.setCheckOutTime(LocalDateTime.now());
                attendanceRepository.save(existing);
                log.info("離場打卡成功: workerId={}, attendanceId={}", profile.getId(), existing.getId());
                return existing;
            } else {
                // Already checked in and out
                throw new BusinessException(400, "今日已完成入場及離場打卡");
            }
        }

        // No record today → create CHECK-IN record
        // Parse check-in type
        CheckInType type;
        try {
            type = CheckInType.valueOf(checkInType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BusinessException(400, "無效的打卡類型: " + checkInType);
        }

        // Create attendance record
        Attendance attendance = Attendance.builder()
                .workerId(profile.getId())
                .siteId(siteId)
                .checkInTime(LocalDateTime.now())
                .checkInType(type)
                .date(today)
                .latitude(latitude)
                .longitude(longitude)
                .build();

        attendance = attendanceRepository.save(attendance);
        log.info("入場打卡成功: workerId={}, siteId={}, type={}", profile.getId(), siteId, type);
        return attendance;
    }

    @Override
    public Page<Attendance> getRecords(Long userId, int page, int size) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "checkInTime"));
        return attendanceRepository.findByWorkerId(profile.getId(), pageable);
    }

    @Override
    public List<Attendance> getRecordsBySite(Long siteId, LocalDate date) {
        return attendanceRepository.findBySiteIdAndDate(siteId, date);
    }

    @Override
    public Map<String, Object> getDailyRecord(Long userId, LocalDate date) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        Optional<Attendance> recordOpt = attendanceRepository.findByWorkerIdAndDate(profile.getId(), date);
        if (recordOpt.isEmpty()) {
            return null;
        }

        Attendance record = recordOpt.get();
        Map<String, Object> result = new HashMap<>();
        result.put("id", record.getId());
        result.put("checkInTime", record.getCheckInTime());
        result.put("checkOutTime", record.getCheckOutTime());
        result.put("date", record.getDate().toString());
        result.put("checkInType", record.getCheckInType() != null ? record.getCheckInType().name() : null);
        result.put("latitude", record.getLatitude());
        result.put("longitude", record.getLongitude());
        result.put("locationAddress", record.getLocationAddress());

        // Get site name
        if (record.getSiteId() != null) {
            Optional<Site> siteOpt = siteRepository.findById(record.getSiteId());
            if (siteOpt.isPresent()) {
                result.put("siteName", siteOpt.get().getName());
            } else {
                result.put("siteName", null);
            }
        } else {
            result.put("siteName", null);
        }

        return result;
    }

    @Override
    public List<Integer> getMonthlyDays(Long userId, int year, int month) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        LocalDate start = LocalDate.of(year, month, 1);
        LocalDate end = start.plusMonths(1).minusDays(1);

        List<Attendance> records = attendanceRepository.findByWorkerIdAndDateBetween(
                profile.getId(), start, end);

        // Also include records where checkOutTime is on the same day (already covered by date field)
        // Return distinct day numbers
        return records.stream()
                .map(r -> r.getDate().getDayOfMonth())
                .distinct()
                .sorted()
                .collect(Collectors.toList());
    }

    /**
     * Haversine 公式计算两点间的球面距离（米）
     */
    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371000; // 地球半径（米）
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}
