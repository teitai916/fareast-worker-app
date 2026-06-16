package com.fareast.worker.service;

/**
 * 人脸验证服务
 */
public interface FaceVerificationService {

    /**
     * 验证两张图片是否是同一个人
     * @param registeredImagePath 已注册的人脸图片路径
     * @param liveBase64 打卡时拍摄的 base64 图片
     * @return 匹配分数（0-100），越高越相似
     */
    int verify(String registeredImagePath, String liveBase64);
}
