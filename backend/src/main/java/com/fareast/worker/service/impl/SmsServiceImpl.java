package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.service.SmsService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class SmsServiceImpl implements SmsService {

    private static final String SMS_CODE_PREFIX = "sms:code:";
    private static final String SMS_RATE_LIMIT_PREFIX = "sms:rate_limit:";
    private static final long CODE_TTL = 5; // minutes
    private static final long RATE_LIMIT_SECONDS = 120;

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @Override
    public void sendSms(String phone) {
        // Mock implementation: just log the SMS sending
        log.debug("【发送短信】手机号: {}，內容: 您的驗證碼為: 123456（模擬）", phone);
    }

    @Override
    public boolean sendVerificationCode(String phone) {
        // 频率限制：同一手机号120秒内只能发送一次
        String rateLimitKey = SMS_RATE_LIMIT_PREFIX + phone;
        if (Boolean.TRUE.equals(redisTemplate.hasKey(rateLimitKey))) {
            Long ttl = redisTemplate.getExpire(rateLimitKey, TimeUnit.SECONDS);
            throw new BusinessException(429, "短信发送过于频繁，请" + ttl + "秒后再试");
        }

        String code = String.format("%06d", ThreadLocalRandom.current().nextInt(0, 999999 + 1));
        String key = SMS_CODE_PREFIX + phone;

        redisTemplate.opsForValue().set(key, code, CODE_TTL, TimeUnit.MINUTES);
        // 设置频率限制
        redisTemplate.opsForValue().set(rateLimitKey, "1", RATE_LIMIT_SECONDS, TimeUnit.SECONDS);

        // In production this would call the Aliyun SMS API
        log.debug("【短信验证码】手机号: {}, 验证码: {}, TTL: {}分钟", phone, code, CODE_TTL);

        return true;
    }

    @Override
    public boolean verifyCode(String phone, String code) {
        String key = SMS_CODE_PREFIX + phone;
        String storedCode = redisTemplate.opsForValue().get(key);

        if (storedCode == null) {
            log.warn("验证码已过期或不存在: {}", phone);
            return false;
        }

        boolean matched = storedCode.equals(code);
        if (matched) {
            // Code verified – delete it to prevent replay
            redisTemplate.delete(key);
            log.debug("验证码校验成功: {}", phone);
        } else {
            log.warn("验证码错误: {}", phone);
        }
        return matched;
    }
}
