package com.fareast.worker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class FareastWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(FareastWorkerApplication.class, args);
    }
}
