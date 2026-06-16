package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.BlacklistRecord;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.SafetyVideo;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SystemConfig;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.service.SuperAdminService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/super-admin")
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class SuperAdminController {

    @Autowired
    private SuperAdminService superAdminService;

    // ===== Users =====

    @GetMapping("/users")
    public ApiResponse<List<User>> getAllUsers() {
        List<User> users = superAdminService.getAllUsers();
        return ApiResponse.success(users);
    }

    @GetMapping("/users/{id}")
    public ApiResponse<User> getUserById(@PathVariable Long id) {
        User user = superAdminService.getUserById(id);
        return ApiResponse.success(user);
    }

    @PostMapping("/users")
    public ApiResponse<User> createUser(@RequestBody User user) {
        User created = superAdminService.createUser(user);
        return ApiResponse.success(created);
    }

    @PutMapping("/users/{id}")
    public ApiResponse<User> updateUser(@PathVariable Long id, @RequestBody User user) {
        User updated = superAdminService.updateUser(id, user);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/users/{id}")
    public ApiResponse<Void> deleteUser(@PathVariable Long id) {
        superAdminService.deleteUser(id);
        return ApiResponse.success(null);
    }

    // ===== Companies =====

    @GetMapping("/companies")
    public ApiResponse<List<Company>> getAllCompanies() {
        List<Company> companies = superAdminService.getAllCompanies();
        return ApiResponse.success(companies);
    }

    @GetMapping("/companies/{id}")
    public ApiResponse<Company> getCompanyById(@PathVariable Long id) {
        Company company = superAdminService.getCompanyById(id);
        return ApiResponse.success(company);
    }

    @PostMapping("/companies")
    public ApiResponse<Company> createCompany(@RequestBody Company company) {
        Company created = superAdminService.createCompany(company);
        return ApiResponse.success(created);
    }

    @PutMapping("/companies/{id}")
    public ApiResponse<Company> updateCompany(@PathVariable Long id, @RequestBody Company company) {
        Company updated = superAdminService.updateCompany(id, company);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/companies/{id}")
    public ApiResponse<Void> deleteCompany(@PathVariable Long id) {
        superAdminService.deleteCompany(id);
        return ApiResponse.success(null);
    }

    // ===== Sites =====

    @GetMapping("/sites")
    public ApiResponse<List<Site>> getAllSites() {
        List<Site> sites = superAdminService.getAllSites();
        return ApiResponse.success(sites);
    }

    @GetMapping("/sites/{id}")
    public ApiResponse<Site> getSiteById(@PathVariable Long id) {
        Site site = superAdminService.getSiteById(id);
        return ApiResponse.success(site);
    }

    @PostMapping("/sites")
    public ApiResponse<Site> createSite(@RequestBody Site site) {
        Site created = superAdminService.createSite(site);
        return ApiResponse.success(created);
    }

    @PutMapping("/sites/{id}")
    public ApiResponse<Site> updateSite(@PathVariable Long id, @RequestBody Site site) {
        Site updated = superAdminService.updateSite(id, site);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/sites/{id}")
    public ApiResponse<Void> deleteSite(@PathVariable Long id) {
        superAdminService.deleteSite(id);
        return ApiResponse.success(null);
    }

    // ===== Blacklist =====

    @GetMapping("/blacklist")
    public ApiResponse<List<BlacklistRecord>> getAllBlacklist() {
        List<BlacklistRecord> records = superAdminService.getAllBlacklistRecords();
        return ApiResponse.success(records);
    }

    @PostMapping("/blacklist")
    public ApiResponse<BlacklistRecord> createBlacklist(@RequestBody BlacklistRecord record) {
        BlacklistRecord created = superAdminService.createBlacklistRecord(record);
        return ApiResponse.success(created);
    }

    @DeleteMapping("/blacklist/{id}")
    public ApiResponse<Void> deleteBlacklist(@PathVariable Long id) {
        superAdminService.deleteBlacklistRecord(id);
        return ApiResponse.success(null);
    }

    @PostMapping("/blacklist/import")
    public ApiResponse<Map<String, Object>> importBlacklist(@RequestParam("file") MultipartFile file) {
        Map<String, Object> result = superAdminService.importBlacklist(file);
        return ApiResponse.success(result);
    }

    // ===== Safety Videos =====

    @GetMapping("/videos")
    public ApiResponse<List<SafetyVideo>> getAllVideos() {
        List<SafetyVideo> videos = superAdminService.getAllVideos();
        return ApiResponse.success(videos);
    }

    @GetMapping("/videos/{id}")
    public ApiResponse<SafetyVideo> getVideoById(@PathVariable Long id) {
        SafetyVideo video = superAdminService.getVideoById(id);
        return ApiResponse.success(video);
    }

    @PostMapping("/videos")
    public ApiResponse<SafetyVideo> createVideo(@RequestBody SafetyVideo video) {
        SafetyVideo created = superAdminService.createVideo(video);
        return ApiResponse.success(created);
    }

    @PutMapping("/videos/{id}")
    public ApiResponse<SafetyVideo> updateVideo(@PathVariable Long id, @RequestBody SafetyVideo video) {
        SafetyVideo updated = superAdminService.updateVideo(id, video);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/videos/{id}")
    public ApiResponse<Void> deleteVideo(@PathVariable Long id) {
        superAdminService.deleteVideo(id);
        return ApiResponse.success(null);
    }

    @GetMapping("/videos/qrcode/{videoId}")
    public ApiResponse<Map<String, String>> getVideoQrCode(@PathVariable Long videoId) {
        String qrCodeBase64 = superAdminService.generateQrCode(videoId);
        return ApiResponse.success(Map.of("qrCode", qrCodeBase64));
    }

    // ===== Attendance =====

    @GetMapping("/attendance")
    public ApiResponse<List<Attendance>> getAllAttendance() {
        List<Attendance> records = superAdminService.getAllAttendance();
        return ApiResponse.success(records);
    }

    @PostMapping("/attendance")
    public ApiResponse<Attendance> createAttendance(@RequestBody Attendance attendance) {
        Attendance created = superAdminService.createAttendance(attendance);
        return ApiResponse.success(created);
    }

    @PutMapping("/attendance")
    public ApiResponse<Attendance> updateAttendance(@RequestBody Attendance attendance) {
        Attendance updated = superAdminService.updateAttendance(attendance);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/attendance")
    public ApiResponse<Void> deleteAttendance(@RequestBody Map<String, Object> requestBody) {
        Long id = Long.valueOf(requestBody.get("id").toString());
        superAdminService.deleteAttendance(id);
        return ApiResponse.success(null);
    }

    // ===== Roles & Permissions =====

    @GetMapping("/roles")
    public ApiResponse<List<String>> getAllRoles() {
        List<String> roles = superAdminService.getAllRoles();
        return ApiResponse.success(roles);
    }

    @PostMapping("/roles")
    public ApiResponse<Map<String, Object>> createRole(@RequestBody Map<String, Object> requestBody) {
        Map<String, Object> result = superAdminService.createRole(requestBody);
        return ApiResponse.success(result);
    }

    @PutMapping("/roles")
    public ApiResponse<Map<String, Object>> updateRole(@RequestBody Map<String, Object> requestBody) {
        Map<String, Object> result = superAdminService.updateRole(requestBody);
        return ApiResponse.success(result);
    }

    @DeleteMapping("/roles")
    public ApiResponse<Void> deleteRole(@RequestBody Map<String, Object> requestBody) {
        String roleName = (String) requestBody.get("role");
        superAdminService.deleteRole(roleName);
        return ApiResponse.success(null);
    }

    @GetMapping("/permissions")
    public ApiResponse<List<String>> getAllPermissions() {
        List<String> permissions = superAdminService.getAllPermissions();
        return ApiResponse.success(permissions);
    }

    @PostMapping("/permissions")
    public ApiResponse<Map<String, Object>> createPermission(@RequestBody Map<String, Object> requestBody) {
        Map<String, Object> result = superAdminService.createPermission(requestBody);
        return ApiResponse.success(result);
    }

    @PutMapping("/permissions")
    public ApiResponse<Map<String, Object>> updatePermission(@RequestBody Map<String, Object> requestBody) {
        Map<String, Object> result = superAdminService.updatePermission(requestBody);
        return ApiResponse.success(result);
    }

    @DeleteMapping("/permissions")
    public ApiResponse<Void> deletePermission(@RequestBody Map<String, Object> requestBody) {
        String permissionName = (String) requestBody.get("permission");
        superAdminService.deletePermission(permissionName);
        return ApiResponse.success(null);
    }

    // ===== Admin Users =====

    @GetMapping("/admin-users")
    public ApiResponse<List<User>> getAdminUsers() {
        List<User> adminUsers = superAdminService.getAdminUsers();
        return ApiResponse.success(adminUsers);
    }

    @PostMapping("/admin-users")
    public ApiResponse<User> createAdminUser(@RequestBody User user) {
        User created = superAdminService.createAdminUser(user);
        return ApiResponse.success(created);
    }

    @PutMapping("/admin-users")
    public ApiResponse<User> updateAdminUser(@RequestBody User user) {
        User updated = superAdminService.updateAdminUser(user);
        return ApiResponse.success(updated);
    }

    @DeleteMapping("/admin-users")
    public ApiResponse<Void> deleteAdminUser(@RequestBody Map<String, Object> requestBody) {
        Long id = Long.valueOf(requestBody.get("id").toString());
        superAdminService.deleteAdminUser(id);
        return ApiResponse.success(null);
    }

    // ===== System Config =====

    @PutMapping("/config/user-agreement")
    public ApiResponse<Void> updateUserAgreement(@RequestBody Map<String, String> requestBody) {
        String content = requestBody.get("content");
        superAdminService.updateConfig("user_agreement", content);
        return ApiResponse.success(null);
    }

    @PutMapping("/config/privacy-policy")
    public ApiResponse<Void> updatePrivacyPolicy(@RequestBody Map<String, String> requestBody) {
        String content = requestBody.get("content");
        superAdminService.updateConfig("privacy_policy", content);
        return ApiResponse.success(null);
    }

    @GetMapping("/config/{key}")
    public ApiResponse<SystemConfig> getConfig(@PathVariable String key) {
        SystemConfig config = superAdminService.getConfig(key);
        return ApiResponse.success(config);
    }
}
