package com.fareast.worker.service;

import com.fareast.worker.model.entity.Announcement;

import java.util.List;

public interface AnnouncementService {

    List<Announcement> getAllAnnouncements();

    Announcement getAnnouncementById(Long id);
}
