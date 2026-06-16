package com.fareast.worker.service;

import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.BlacklistRecord;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SystemConfig;
import com.fareast.worker.model.entity.User;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

public interface SuperAdminService {

    // ===== Users =====

    List<User> getAllUsers();

    User getUserById(Long id);

    User createUser(User user);

    User updateUser(Long id, User user);

    void deleteUser(Long id);

    // ===== Companies =====

    List<Company> getAllCompanies();

    Company getCompanyById(Long id);

    Company createCompany(Company company);

    Company updateCompany(Long id, Company company);

    void deleteCompany(Long id);

    // ===== Sites =====

    List<Site> getAllSites();

    Site getSiteById(Long id);

    Site createSite(Site site);

    Site updateSite(Long id, Site site);

    void deleteSite(Long id);

    // ===== Blacklist =====

    List<BlacklistRecord> getAllBlacklistRecords();

    BlacklistRecord createBlacklistRecord(BlacklistRecord record);

    void deleteBlacklistRecord(Long id);

    Map<String, Object> importBlacklist(MultipartFile file);

    // ===== Safety Videos =====

    List<SafetyVideo> getAllVideos();

    SafetyVideo getVideoById(Long id);

    SafetyVideo createVideo(SafetyVideo video);

    SafetyVideo updateVideo(Long id, SafetyVideo video);

    void deleteVideo(Long id);

    String generateQrCode(Long videoId);

    // ===== Attendance =====

    List<Attendance> getAllAttendance();

    Attendance createAttendance(Attendance attendance);

    Attendance updateAttendance(Attendance attendance);

    void deleteAttendance(Long id);

    // ===== Roles & Permissions =====

    List<String> getAllRoles();

    Map<String, Object> createRole(Map<String, Object> requestBody);

    Map<String, Object> updateRole(Map<String, Object> requestBody);

    void deleteRole(String roleName);

    List<String> getAllPermissions();

    Map<String, Object> createPermission(Map<String, Object> requestBody);

    Map<String, Object> updatePermission(Map<String, Object> requestBody);

    void deletePermission(String permissionName);

    // ===== Admin Users =====

    List<User> getAdminUsers();

    User createAdminUser(User user);

    User updateAdminUser(User user);

    void deleteAdminUser(Long id);

    // ===== System Config =====

    void updateConfig(String key, String value);

    SystemConfig getConfig(String key);
}
