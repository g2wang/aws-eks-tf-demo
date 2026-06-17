package com.example.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
public class Controller {

    private static final Logger logger = LoggerFactory.getLogger(Controller.class);

    @GetMapping("/time")
    public Map<String, Object> getTime() {
        long epochMs = System.currentTimeMillis();
        String readableTime = Instant.ofEpochMilli(epochMs).toString();

        logger.info("Handling request to /time: epoch_ms={}, readable_time={}", epochMs, readableTime);

        Map<String, Object> response = new HashMap<>();
        response.put("epoch_ms", epochMs);
        response.put("readable_time", readableTime);
        response.put("service", "time-service");
        response.put("status", "UP");

        return response;
    }

    @GetMapping("/")
    public Map<String, String> index() {
        logger.info("Handling request to root /");
        Map<String, String> response = new HashMap<>();
        response.put("message", "EKS Time Service is running. Use GET /time to retrieve epoch milliseconds.");
        return response;
    }
}
