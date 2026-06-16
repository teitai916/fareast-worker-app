package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Announcement;
import com.fareast.worker.service.AnnouncementService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/announcements")
public class AnnouncementController {

    @Autowired
    private AnnouncementService announcementService;

    @GetMapping
    public ApiResponse<List<Announcement>> listAnnouncements() {
        List<Announcement> announcements = announcementService.getAllAnnouncements();
        return ApiResponse.success(announcements);
    }

    @GetMapping("/{id}")
    public ApiResponse<Announcement> getAnnouncement(@PathVariable Long id) {
        Announcement announcement = announcementService.getAnnouncementById(id);
        return ApiResponse.success(announcement);
    }
}
