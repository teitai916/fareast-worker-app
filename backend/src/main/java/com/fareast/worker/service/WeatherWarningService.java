package com.fareast.worker.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import jakarta.annotation.PostConstruct;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * 天气警告服务 - 定时从香港天文台获取台风/暴雨/酷热/工作暑热警告
 * 每20分钟轮询，写入Redis（TTL=20分钟）
 */
@Slf4j
@Service
public class WeatherWarningService {

    private static final String WEATHER_WARNINGS_URL =
            "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=warnsum&lang=tc";
    private static final String HSWW_URL =
            "https://data.weather.gov.hk/weatherAPI/opendata/hsww.php?lang=tc";

    private static final String REDIS_KEY_WARNINGS = "weather:warnings";
    private static final String REDIS_KEY_HSWW = "weather:hsww";
    private static final long TTL_MINUTES = 20;

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * 启动后立即执行一次
     */
    @PostConstruct
    public void init() {
        log.info("WeatherWarningService 初始化，开始首次拉取天气警告...");
        fetchWeatherWarnings();
    }

    /**
     * 每20分钟定时拉取天气警告
     */
    @Scheduled(fixedDelay = 1_200_000) // 20分钟
    public void fetchWeatherWarnings() {
        try {
            // 1. 拉取天气警告一览（warnsum）
            String warnsumJson = restTemplate.getForObject(WEATHER_WARNINGS_URL, String.class);
            if (warnsumJson != null && !warnsumJson.isEmpty()) {
                redisTemplate.opsForValue().set(REDIS_KEY_WARNINGS, warnsumJson,
                        Duration.ofMinutes(TTL_MINUTES));
                log.info("天气警告已更新，大小={}bytes", warnsumJson.length());
            } else {
                log.warn("warnsum API 返回空數據");
            }
        } catch (Exception e) {
            log.error("拉取 warnsum 天氣警告失败: {}", e.getMessage());
        }

        try {
            // 2. 拉取工作暑热警告（HSWW）
            String hswwJson = restTemplate.getForObject(HSWW_URL, String.class);
            if (hswwJson != null && !hswwJson.isEmpty()) {
                redisTemplate.opsForValue().set(REDIS_KEY_HSWW, hswwJson,
                        Duration.ofMinutes(TTL_MINUTES));
                log.info("工作暑熱警告已更新，大小={}bytes", hswwJson.length());
            } else {
                log.info("HSWW API 返回空數據（暫無生效中的工作暑熱警告）");
                // 无生效警告时也缓存空标记
                redisTemplate.opsForValue().set(REDIS_KEY_HSWW, "{}", Duration.ofMinutes(TTL_MINUTES));
            }
        } catch (Exception e) {
            log.error("拉取 HSWW 工作暑熱警告失败: {}", e.getMessage());
        }
    }

    /**
     * 获取缓存的天气警告数据
     */
    public String getWarnsum() {
        String cached = redisTemplate.opsForValue().get(REDIS_KEY_WARNINGS);
        return cached != null ? cached : "{}";
    }

    /**
     * 获取缓存的工作暑热警告数据
     */
    public String getHsww() {
        String cached = redisTemplate.opsForValue().get(REDIS_KEY_HSWW);
        return cached != null ? cached : "{}";
    }
}
