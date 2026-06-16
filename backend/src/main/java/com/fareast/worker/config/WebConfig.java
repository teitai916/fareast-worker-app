package com.fareast.worker.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    // CORS 已统一由 SecurityConfig.corsConfigurationSource() 管理
}
