package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.entity.WorkerSite;
import com.fareast.worker.model.enums.CheckInType;
import com.fareast.worker.repository.AttendanceRepository;
import com.fareast.worker.repository.SafetyVideoRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.WorkerSiteRepository;
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
    private WorkerSiteRepository workerSiteRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Value("${checkin.max-distance:300}")
    private double maxDistance; // 打卡最大允许距离（米）

    @Value("${file.upload-dir:./uploads}")
    private String uploadDir;

    @Override
    @Transactional
    public Attendance checkIn(Long userId, Double latitude, Double longitude, String checkInType, Long siteId, String bluetoothBeaconId, java.util.List<java.util.Map<String, Object>> nearbyBeacons, String photoBase64) {
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

        // 多地盘支持：如果未指定siteId，取 worker_sites 中第一个地盘
        if (siteId == null) {
            List<WorkerSite> wsList = workerSiteRepository.findByWorkerId(profile.getId());
            if (wsList.isEmpty()) {
                throw new BusinessException(400, "請先加入一個地盤");
            }
            siteId = wsList.get(0).getSiteId();
        } else {
            // 验证工人是否已加入该地盘
            java.util.Optional<WorkerSite> ws = workerSiteRepository
                    .findByWorkerIdAndSiteId(profile.getId(), siteId);
            if (ws.isEmpty()) {
                throw new BusinessException(400, "您未加入此地盤，請先申請加入");
            }
        }

        // Check face registration (已注释 - App Store 合规，改为拍照存档)
        // if (!Boolean.TRUE.equals(profile.getFaceRegistered())) {
        //     throw new BusinessException(400, "請先完成人臉登記");
        // }

        // Check mandatory safety videos
        List<SafetyVideo> mandatoryVideos = safetyVideoRepository.findAll().stream()
                .filter(SafetyVideo::getMandatory)
                .collect(Collectors.toList());

        if (!mandatoryVideos.isEmpty()) {
            int completedCount = workerVideoViewRepository.countByWorkerIdAndCompletedTrue(userId);
            if (completedCount < mandatoryVideos.size()) {
                log.warn("工人未完成安全培訓: userId={}, completed={}/{}",
                        userId, completedCount, mandatoryVideos.size());
                throw new BusinessException(400, "請先完成安全培訓影片");
            }
        }

        // Parse check-in type
        CheckInType type;
        try {
            type = CheckInType.valueOf(checkInType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BusinessException(400, "無效的打卡類型: " + checkInType);
        }

        // Load site
        Site site = siteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException(404, "地盤資訊不存在"));

        LocalDate today = LocalDate.now();

        // ─── GPS 验证 / 蓝牙信标验证 ───
        if (type == CheckInType.BLUETOOTH) {
            // 蓝牙打卡：验证信标 UUID
            String siteBeaconIds = site.getBluetoothBeaconId();
            if (siteBeaconIds == null || siteBeaconIds.trim().isEmpty()) {
                throw new BusinessException(400, "該地盤未配置藍牙信標，請使用GPS打卡");
            }
            if (bluetoothBeaconId == null || bluetoothBeaconId.trim().isEmpty()) {
                throw new BusinessException(400, "未檢測到藍牙信標，請確認藍牙已開啟並在地盤範圍內");
            }

            // 逗号分割多信标，逐一比对（忽略大小写）
            boolean beaconMatched = false;
            String[] beaconArray = siteBeaconIds.split(",");
            for (String configuredBeacon : beaconArray) {
                if (configuredBeacon.trim().equalsIgnoreCase(bluetoothBeaconId.trim())) {
                    beaconMatched = true;
                    break;
                }
            }

            if (!beaconMatched) {
                log.warn("藍牙信標不匹配: workerId={}, siteId={}, received={}, site={}",
                        profile.getId(), siteId, bluetoothBeaconId, siteBeaconIds);
                throw new BusinessException(400, "未檢測到正確的地盤藍牙信標，請確認您在地盤範圍內");
            }

            log.info("藍牙信標驗證通過: workerId={}, siteId={}, beaconId={}",
                    profile.getId(), siteId, bluetoothBeaconId);

            // 记录附近扫描到的所有 Beacon（前端上报的扫描结果）
            if (nearbyBeacons != null && !nearbyBeacons.isEmpty()) {
                log.info("===== 附近 Beacon 掃描結果 (workerId={}, siteId={}) =====", profile.getId(), siteId);
                for (java.util.Map<String, Object> beacon : nearbyBeacons) {
                    String bUuid = (String) beacon.getOrDefault("uuid", "?");
                    Object bRssi = beacon.getOrDefault("rssi", "?");
                    Object bDistance = beacon.getOrDefault("distance", "?");
                    String indent = bUuid.equalsIgnoreCase(bluetoothBeaconId) ? ">>> [匹配] " : "    ";
                    log.info("{}{}  RSSI={}  估算距離={}m", indent, bUuid, bRssi, bDistance);
                }
                log.info("===== 共 {} 個 Beacon =====", nearbyBeacons.size());
            } else {
                log.info("附近 Beacon 掃描結果: 無 (前端未上報或掃描期間無發現)");
            }

            // 蓝牙验证通过，跳过 GPS 地理围栏校验
            // GPS 仅记录，不做距离验证

        } else if (type == CheckInType.GPS) {
            // GPS打卡：地理围栏校验
            log.info("打卡請求: workerId={}, siteId={}, lat={}, lng={}",
                    profile.getId(), siteId, latitude, longitude);
            if (latitude == null || longitude == null) {
                throw new BusinessException(400, "無法獲取定位資訊，請開啟 GPS");
            }
            if (site.getLatitude() == null || site.getLongitude() == null) {
                log.warn("地盤 {} 經緯度未設定，跳過地理圍欄檢查", siteId);
            } else {
                double distance = calculateDistance(
                        latitude, longitude,
                        site.getLatitude(), site.getLongitude());
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
        }
        // MANUAL 类型不验证，仅内部人员使用

        // Check if already has a record today
        Optional<Attendance> existingOpt = attendanceRepository.findByWorkerIdAndDate(profile.getId(), today);

        if (existingOpt.isPresent()) {
            Attendance existing = existingOpt.get();
            // If checkOutTime is null → this is a CHECK-OUT
            if (existing.getCheckOutTime() == null) {
                // Process check-out photo (if provided)
                if (photoBase64 != null && !photoBase64.isEmpty()) {
                    String outPhotoUrl = savePhoto(profile.getId(), today, photoBase64, "checkout");
                    existing.setCheckOutPhotoUrl(outPhotoUrl);
                }
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
        // Process check-in photo (if provided)
        String checkInPhotoUrl = null;
        if (photoBase64 != null && !photoBase64.isEmpty()) {
            checkInPhotoUrl = savePhoto(profile.getId(), today, photoBase64, "checkin");
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
                .bluetoothBeaconId(bluetoothBeaconId)
                .checkInPhotoUrl(checkInPhotoUrl)
                .build();

        attendance = attendanceRepository.save(attendance);
        log.info("入場打卡成功: workerId={}, siteId={}, type={}, beaconId={}", profile.getId(), siteId, type, bluetoothBeaconId);
        return attendance;
    }

    /**
     * Save a check-in/check-out photo from Base64 to disk.
     * @return the URL path, or null if failed (does not throw).
     */
    private String savePhoto(Long workerId, java.time.LocalDate date, String base64, String prefix) {
        try {
            byte[] photoBytes = java.util.Base64.getDecoder().decode(base64);
            String photosDir = uploadDir + "/photos/";
            java.nio.file.Files.createDirectories(java.nio.file.Paths.get(photosDir));
            String fileName = prefix + "_" + workerId + "_" + date + "_" + java.util.UUID.randomUUID().toString().substring(0, 8) + ".jpg";
            java.nio.file.Path destPath = java.nio.file.Paths.get(photosDir + fileName);
            java.nio.file.Files.write(destPath, photoBytes);
            String url = "/uploads/photos/" + fileName;
            log.info("打卡照片已保存: workerId={}, type={}, url={}, size={}bytes", workerId, prefix, url, photoBytes.length);
            return url;
        } catch (Exception e) {
            log.warn("打卡照片保存失败 (不阻斷打卡): workerId={}, type={}, error={}", workerId, prefix, e.getMessage());
            return null;
        }
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
