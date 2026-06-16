package com.fareast.worker.service;

public interface SmsService {

    /**
     * Send a 6-digit verification code to the given phone number.
     * In production this would call Aliyun SMS API; in dev the code is logged.
     */
    boolean sendVerificationCode(String phone);

    /**
     * Verify the code entered by the user against the value stored in Redis.
     */
    boolean verifyCode(String phone, String code);

    /**
     * Send SMS to the given phone number.
     */
    void sendSms(String phone);
}
