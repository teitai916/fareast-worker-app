package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.service.AttendanceService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/attendance")
@PreAuthorize("hasRole('WORKER')")
public class AttendanceController {

    @Autowired
    private AttendanceService attendanceService;

    @Autowired
    private SiteRepository siteRepository;

    @PostMapping("/check-in")
    public ApiResponse<Map<String, Object>> checkIn(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Double latitude = requestBody.get("latitude") != null ? Double.valueOf(requestBody.get("latitude").toString()) : null;
        Double longitude = requestBody.get("longitude") != null ? Double.valueOf(requestBody.get("longitude").toString()) : null;
        String checkInType = (String) requestBody.get("checkInType");
        Long siteId = requestBody.get("siteId") != null ? Long.valueOf(requestBody.get("siteId").toString()) : null;
        String bluetoothBeaconId = (String) requestBody.get("bluetoothBeaconId");
        @SuppressWarnings("unchecked")
        java.util.List<java.util.Map<String, Object>> nearbyBeacons = (java.util.List<java.util.Map<String, Object>>) requestBody.get("nearbyBeacons");
        String photoBase64 = (String) requestBody.get("photo");

        Attendance attendance = attendanceService.checkIn(Long.valueOf(userId), latitude, longitude, checkInType, siteId, bluetoothBeaconId, nearbyBeacons, photoBase64);

        // Build response map (include site name)
        Map<String, Object> data = new HashMap<>();
        data.put("id", attendance.getId());
        data.put("checkInTime", attendance.getCheckInTime());
        data.put("checkOutTime", attendance.getCheckOutTime());
        data.put("date", attendance.getDate());
        data.put("checkInType", attendance.getCheckInType() != null ? attendance.getCheckInType().name() : null);
        data.put("latitude", attendance.getLatitude());
        data.put("longitude", attendance.getLongitude());
        data.put("locationAddress", attendance.getLocationAddress());
        data.put("bluetoothBeaconId", attendance.getBluetoothBeaconId());
        data.put("checkInPhotoUrl", attendance.getCheckInPhotoUrl());
        data.put("checkOutPhotoUrl", attendance.getCheckOutPhotoUrl());

        // Get site name
        if (attendance.getSiteId() != null) {
            Optional<Site> siteOpt = siteRepository.findById(attendance.getSiteId());
            if (siteOpt.isPresent()) {
                data.put("siteName", siteOpt.get().getName());
            } else {
                data.put("siteName", null);
            }
        } else {
            data.put("siteName", null);
        }

        return ApiResponse.success(data);
    }

    @GetMapping("/records")
    public ApiResponse<Map<String, Object>> getRecords(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        org.springframework.data.domain.Page<Attendance> records = attendanceService.getRecords(Long.valueOf(userId), page, size);

        Map<String, Object> pageResponse = new HashMap<>();
        pageResponse.put("content", records.getContent());
        pageResponse.put("page", records.getNumber());
        pageResponse.put("size", records.getSize());
        pageResponse.put("totalElements", records.getTotalElements());
        pageResponse.put("totalPages", records.getTotalPages());
        pageResponse.put("first", records.isFirst());
        pageResponse.put("last", records.isLast());

        return ApiResponse.success(pageResponse);
    }

    @GetMapping("/daily")
    public ApiResponse<Map<String, Object>> getDailyRecord(
            @AuthenticationPrincipal String userId,
            @RequestParam String date) {
        LocalDate localDate = LocalDate.parse(date);
        Map<String, Object> record = attendanceService.getDailyRecord(Long.valueOf(userId), localDate);
        return ApiResponse.success(record);
    }

    @GetMapping("/monthly")
    public ApiResponse<List<Integer>> getMonthlyDays(
            @AuthenticationPrincipal String userId,
            @RequestParam int year,
            @RequestParam int month) {
        List<Integer> days = attendanceService.getMonthlyDays(Long.valueOf(userId), year, month);
        return ApiResponse.success(days);
    }
}
