package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.*;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.model.enums.UserStatus;
import com.fareast.worker.repository.*;
import com.fareast.worker.service.SuperAdminService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
public class SuperAdminServiceImpl implements SuperAdminService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private BlacklistRecordRepository blacklistRecordRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private SafetyVideoRepository safetyVideoRepository;

    @Autowired
    private AttendanceRepository attendanceRepository;

    @Autowired
    private SystemConfigRepository systemConfigRepository;

    // ===== Users =====

    @Override
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    @Override
    public User getUserById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
    }

    @Override
    @Transactional
    public User createUser(User user) {
        User saved = userRepository.save(user);
        log.info("用戶已新增: userId={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional
    public User updateUser(Long id, User user) {
        User existing = userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        if (user.getName() != null) existing.setName(user.getName());
        if (user.getPhone() != null) existing.setPhone(user.getPhone());
        if (user.getRole() != null) existing.setRole(user.getRole());
        if (user.getStatus() != null) existing.setStatus(user.getStatus());

        User saved = userRepository.save(existing);
        log.info("用戶已更新: userId={}", id);
        return saved;
    }

    @Override
    @Transactional
    public void deleteUser(Long id) {
        if (!userRepository.existsById(id)) {
            throw new BusinessException(404, "用戶不存在");
        }
        userRepository.deleteById(id);
        log.info("用戶已刪除: userId={}", id);
    }

    // ===== Companies =====

    @Override
    public List<Company> getAllCompanies() {
        return companyRepository.findAll();
    }

    @Override
    public Company getCompanyById(Long id) {
        return companyRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "公司不存在"));
    }

    @Override
    @Transactional
    public Company createCompany(Company company) {
        company.setCreatedAt(null);
        company.setUpdatedAt(null);
        Company saved = companyRepository.save(company);
        log.info("公司已新增: companyId={}, name={}", saved.getId(), saved.getName());
        return saved;
    }

    @Override
    @Transactional
    public Company updateCompany(Long id, Company company) {
        Company existing = companyRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "公司不存在"));

        if (company.getName() != null) existing.setName(company.getName());
        if (company.getAddress() != null) existing.setAddress(company.getAddress());
        if (company.getContactPerson() != null) existing.setContactPerson(company.getContactPerson());
        if (company.getContactPhone() != null) existing.setContactPhone(company.getContactPhone());

        Company saved = companyRepository.save(existing);
        log.info("公司已更新: companyId={}", id);
        return saved;
    }

    @Override
    @Transactional
    public void deleteCompany(Long id) {
        if (!companyRepository.existsById(id)) {
            throw new BusinessException(404, "公司不存在");
        }
        companyRepository.deleteById(id);
        log.info("公司已刪除: companyId={}", id);
    }

    // ===== Sites =====

    @Override
    public List<Site> getAllSites() {
        return siteRepository.findAll();
    }

    @Override
    public Site getSiteById(Long id) {
        return siteRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "地盤不存在"));
    }

    @Override
    @Transactional
    public Site createSite(Site site) {
        Site saved = siteRepository.save(site);
        log.info("地盤已新增: siteId={}, name={}", saved.getId(), saved.getName());
        return saved;
    }

    @Override
    @Transactional
    public Site updateSite(Long id, Site site) {
        Site existing = siteRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "地盤不存在"));

        if (site.getName() != null) existing.setName(site.getName());
        if (site.getAddress() != null) existing.setAddress(site.getAddress());
        if (site.getCompanyId() != null) existing.setCompanyId(site.getCompanyId());
        if (site.getLatitude() != null) existing.setLatitude(site.getLatitude());
        if (site.getLongitude() != null) existing.setLongitude(site.getLongitude());
        if (site.getManagerName() != null) existing.setManagerName(site.getManagerName());
        if (site.getManagerPhone() != null) existing.setManagerPhone(site.getManagerPhone());
        if (site.getBluetoothBeaconId() != null) existing.setBluetoothBeaconId(site.getBluetoothBeaconId());

        Site saved = siteRepository.save(existing);
        log.info("地盤已更新: siteId={}", id);
        return saved;
    }

    @Override
    @Transactional
    public void deleteSite(Long id) {
        if (!siteRepository.existsById(id)) {
            throw new BusinessException(404, "地盤不存在");
        }
        siteRepository.deleteById(id);
        log.info("地盤已刪除: siteId={}", id);
    }

    // ===== Blacklist =====

    @Override
    public List<BlacklistRecord> getAllBlacklistRecords() {
        return blacklistRecordRepository.findAll();
    }

    @Override
    @Transactional
    public BlacklistRecord createBlacklistRecord(BlacklistRecord record) {
        record.setAddedAt(LocalDateTime.now());
        BlacklistRecord saved = blacklistRecordRepository.save(record);

        workerProfileRepository.findById(record.getWorkerId()).ifPresent(profile -> {
            profile.setBlacklisted(true);
            profile.setBlacklistReason(record.getReason());
            workerProfileRepository.save(profile);
        });

        log.info("黑名單記錄已新增: workerId={}", record.getWorkerId());
        return saved;
    }

    @Override
    @Transactional
    public void deleteBlacklistRecord(Long id) {
        BlacklistRecord record = blacklistRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "黑名單記錄不存在"));

        workerProfileRepository.findById(record.getWorkerId()).ifPresent(profile -> {
            profile.setBlacklisted(false);
            profile.setBlacklistReason(null);
            workerProfileRepository.save(profile);
        });

        blacklistRecordRepository.deleteById(id);
        log.info("黑名單記錄已刪除: recordId={}", id);
    }

    @Override
    @Transactional
    public Map<String, Object> importBlacklist(MultipartFile file) {
        int count = 0;
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8))) {

            String line;
            // Skip header row
            reader.readLine();

            while ((line = reader.readLine()) != null) {
                String[] fields = line.split(",");
                if (fields.length < 2) continue;

                String workerNumber = fields[0].trim();
                String reason = fields[1].trim();

                Optional<WorkerProfile> profileOpt = workerProfileRepository.findByWorkerNumber(workerNumber);
                if (profileOpt.isPresent()) {
                    WorkerProfile profile = profileOpt.get();
                    profile.setBlacklisted(true);
                    profile.setBlacklistReason(reason);
                    workerProfileRepository.save(profile);

                    BlacklistRecord record = BlacklistRecord.builder()
                            .workerId(profile.getId())
                            .reason(reason)
                            .addedAt(LocalDateTime.now())
                            .build();
                    blacklistRecordRepository.save(record);
                    count++;
                }
            }
        } catch (Exception e) {
            log.error("黑名單導入失敗", e);
            throw new BusinessException(500, "黑名單導入失敗: " + e.getMessage());
        }

        log.info("黑名單批量導入完成: 共導入 {} 條", count);
        Map<String, Object> result = new HashMap<>();
        result.put("imported", count);
        result.put("message", "成功導入 " + count + " 條記錄");
        return result;
    }

    // ===== Safety Videos =====

    @Override
    public List<SafetyVideo> getAllVideos() {
        return safetyVideoRepository.findAll();
    }

    @Override
    public SafetyVideo getVideoById(Long id) {
        return safetyVideoRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "安全培訓影片不存在"));
    }

    @Override
    @Transactional
    public SafetyVideo createVideo(SafetyVideo video) {
        SafetyVideo saved = safetyVideoRepository.save(video);
        log.info("安全培訓影片已新增: videoId={}, title={}", saved.getId(), saved.getTitle());
        return saved;
    }

    @Override
    @Transactional
    public SafetyVideo updateVideo(Long id, SafetyVideo video) {
        SafetyVideo existing = safetyVideoRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "安全培訓影片不存在"));

        if (video.getTitle() != null) existing.setTitle(video.getTitle());
        if (video.getDescription() != null) existing.setDescription(video.getDescription());
        if (video.getVideoUrl() != null) existing.setVideoUrl(video.getVideoUrl());
        if (video.getDuration() != null) existing.setDuration(video.getDuration());
        if (video.getMandatory() != null) existing.setMandatory(video.getMandatory());

        SafetyVideo saved = safetyVideoRepository.save(existing);
        log.info("安全培訓影片已更新: videoId={}", id);
        return saved;
    }

    @Override
    @Transactional
    public void deleteVideo(Long id) {
        if (!safetyVideoRepository.existsById(id)) {
            throw new BusinessException(404, "安全培訓影片不存在");
        }
        safetyVideoRepository.deleteById(id);
        log.info("安全培訓影片已刪除: videoId={}", id);
    }

    @Override
    @Transactional
    public String generateQrCode(Long videoId) {
        SafetyVideo video = safetyVideoRepository.findById(videoId)
                .orElseThrow(() -> new BusinessException(404, "安全培訓影片不存在"));

        String qrCodeUrl = "/api/safety/videos/" + videoId + "/qr";
        video.setQrCodeUrl(qrCodeUrl);
        safetyVideoRepository.save(video);

        log.info("安全培訓影片QR碼已生成: videoId={}, qrUrl={}", videoId, qrCodeUrl);
        return qrCodeUrl;
    }

    // ===== Attendance =====

    @Override
    public List<Attendance> getAllAttendance() {
        return attendanceRepository.findAll();
    }

    @Override
    @Transactional
    public Attendance createAttendance(Attendance attendance) {
        Attendance saved = attendanceRepository.save(attendance);
        log.info("考勤記錄已新增: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional
    public Attendance updateAttendance(Attendance attendance) {
        Attendance existing = attendanceRepository.findById(attendance.getId())
                .orElseThrow(() -> new BusinessException(404, "考勤記錄不存在"));

        if (attendance.getWorkerId() != null) existing.setWorkerId(attendance.getWorkerId());
        if (attendance.getSiteId() != null) existing.setSiteId(attendance.getSiteId());
        if (attendance.getDate() != null) existing.setDate(attendance.getDate());
        if (attendance.getCheckInTime() != null) existing.setCheckInTime(attendance.getCheckInTime());
        if (attendance.getCheckOutTime() != null) existing.setCheckOutTime(attendance.getCheckOutTime());

        Attendance saved = attendanceRepository.save(existing);
        log.info("考勤記錄已更新: id={}", attendance.getId());
        return saved;
    }

    @Override
    @Transactional
    public void deleteAttendance(Long id) {
        if (!attendanceRepository.existsById(id)) {
            throw new BusinessException(404, "考勤記錄不存在");
        }
        attendanceRepository.deleteById(id);
        log.info("考勤記錄已刪除: id={}", id);
    }

    // ===== Roles & Permissions =====

    @Override
    public List<String> getAllRoles() {
        List<String> roles = new ArrayList<>();
        for (UserRole role : UserRole.values()) {
            roles.add(role.name());
        }
        return roles;
    }

    @Override
    @Transactional
    public Map<String, Object> createRole(Map<String, Object> requestBody) {
        log.info("角色新增請求 (當前僅支援預定義角色): {}", requestBody);
        throw new BusinessException(400, "當前版本僅支援預定義角色，無法自定義新增");
    }

    @Override
    @Transactional
    public Map<String, Object> updateRole(Map<String, Object> requestBody) {
        log.info("角色編輯請求: {}", requestBody);
        throw new BusinessException(400, "當前版本僅支援預定義角色，無法自定義編輯");
    }

    @Override
    @Transactional
    public void deleteRole(String roleName) {
        throw new BusinessException(400, "當前版本僅支援預定義角色，無法刪除");
    }

    @Override
    public List<String> getAllPermissions() {
        List<String> permissions = new ArrayList<>();
        permissions.add("user:view");
        permissions.add("user:edit");
        permissions.add("user:disable");
        permissions.add("company:view");
        permissions.add("company:edit");
        permissions.add("company:delete");
        permissions.add("site:view");
        permissions.add("site:edit");
        permissions.add("site:delete");
        permissions.add("blacklist:view");
        permissions.add("blacklist:edit");
        permissions.add("blacklist:import");
        permissions.add("safety_video:view");
        permissions.add("safety_video:edit");
        permissions.add("attendance:view");
        permissions.add("attendance:export");
        permissions.add("config:view");
        permissions.add("config:edit");
        return permissions;
    }

    @Override
    @Transactional
    public Map<String, Object> createPermission(Map<String, Object> requestBody) {
        log.info("權限新增請求 (當前僅支援預定義權限): {}", requestBody);
        throw new BusinessException(400, "當前版本僅支援預定義權限，無法自定義新增");
    }

    @Override
    @Transactional
    public Map<String, Object> updatePermission(Map<String, Object> requestBody) {
        log.info("權限編輯請求: {}", requestBody);
        throw new BusinessException(400, "當前版本僅支援預定義權限，無法自定義編輯");
    }

    @Override
    @Transactional
    public void deletePermission(String permissionName) {
        throw new BusinessException(400, "當前版本僅支援預定義權限，無法刪除");
    }

    // ===== Admin Users =====

    @Override
    public List<User> getAdminUsers() {
        return userRepository.findAll().stream()
                .filter(u -> u.getRole() == UserRole.SITE_MANAGER || u.getRole() == UserRole.PROJECT_MANAGER
                        || u.getRole() == UserRole.INSTALL_MANAGER)
                .toList();
    }

    @Override
    @Transactional
    public User createAdminUser(User user) {
        if (user.getRole() == UserRole.WORKER || user.getRole() == UserRole.CONTRACTOR
                || user.getRole() == UserRole.SAFETY_OFFICER || user.getRole() == UserRole.NOTIFIED_PARTY) {
            throw new BusinessException(400, "管理員角色不能為工人、分判商、安全人員或知會人員");
        }
        User saved = userRepository.save(user);
        log.info("管理員已新增: userId={}, role={}", saved.getId(), saved.getRole());
        return saved;
    }

    @Override
    @Transactional
    public User updateAdminUser(User user) {
        User existing = userRepository.findById(user.getId())
                .orElseThrow(() -> new BusinessException(404, "管理員不存在"));

        if (user.getName() != null) existing.setName(user.getName());
        if (user.getPhone() != null) existing.setPhone(user.getPhone());
        if (user.getRole() != null) existing.setRole(user.getRole());
        if (user.getStatus() != null) existing.setStatus(user.getStatus());

        User saved = userRepository.save(existing);
        log.info("管理員已更新: userId={}", user.getId());
        return saved;
    }

    @Override
    @Transactional
    public void deleteAdminUser(Long id) {
        if (!userRepository.existsById(id)) {
            throw new BusinessException(404, "管理員不存在");
        }
        userRepository.deleteById(id);
        log.info("管理員已刪除: userId={}", id);
    }

    // ===== System Config =====

    @Override
    @Transactional
    public void updateConfig(String key, String value) {
        SystemConfig config = systemConfigRepository.findByConfigKey(key).orElse(null);
        if (config == null) {
            config = SystemConfig.builder()
                    .configKey(key)
                    .configValue(value)
                    .build();
        } else {
            config.setConfigValue(value);
        }
        systemConfigRepository.save(config);
        log.info("系統配置已更新: key={}", key);
    }

    @Override
    public SystemConfig getConfig(String key) {
        return systemConfigRepository.findByConfigKey(key)
                .orElseThrow(() -> new BusinessException(404, "配置項不存在: " + key));
    }
}
