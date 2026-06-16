package com.fareast.worker.service.impl;

import com.fareast.worker.service.FaceVerificationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.awt.image.ColorConvertOp;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.util.Base64;

/**
 * 基于 pHash（感知哈希）的人脸对比实现
 * 流程：缩小 → 灰度 → DCT → 取低频 → 计算哈希 → 汉明距离 → 相似度分数
 */
@Slf4j
@Service
public class FaceVerificationServiceImpl implements FaceVerificationService {

    private static final int HASH_SIZE = 8;    // 8x8 DCT 低频系数
    private static final int SMALL_SIZE = 32;   // 缩小到 32x32

    @Override
    public int verify(String registeredImagePath, String liveBase64) {
        try {
            // 1. 读取注册图片
            BufferedImage registeredImage = ImageIO.read(new File(registeredImagePath));
            if (registeredImage == null) {
                log.warn("无法读取注册图片: {}", registeredImagePath);
                return 0;
            }

            // 2. 解码实时拍摄的 base64 图片
            byte[] imageBytes = Base64.getDecoder().decode(liveBase64);
            BufferedImage liveImage = ImageIO.read(new ByteArrayInputStream(imageBytes));
            if (liveImage == null) {
                log.warn("无法解码实时拍摄图片");
                return 0;
            }

            // 3. 计算两张图片的 pHash
            String hash1 = computePHash(registeredImage);
            String hash2 = computePHash(liveImage);

            // 4. 计算汉明距离
            int hammingDistance = hammingDistance(hash1, hash2);

            // 5. 转换为相似度分数（0-100）
            // 汉明距离范围 0-64，距离越小越相似
            int score = Math.max(0, (int) ((1.0 - (double) hammingDistance / (HASH_SIZE * HASH_SIZE)) * 100));

            log.info("人脸验证: registered={}, score={}, hammingDistance={}",
                    registeredImagePath, score, hammingDistance);
            return score;

        } catch (IOException e) {
            log.error("人脸验证图片处理失败: {}", e.getMessage());
            return 0;
        }
    }

    /**
     * 计算图片的感知哈希值
     */
    String computePHash(BufferedImage image) {
        // 1. 缩小到 32x32
        BufferedImage smallImage = resize(image, SMALL_SIZE, SMALL_SIZE);

        // 2. 转换为灰度图
        BufferedImage grayImage = toGrayscale(smallImage);

        // 3. 计算 DCT（简化：直接取像素值作为频域近似）
        double[][] dctData = dct(grayImage);

        // 4. 取左上角 8x8 低频系数
        double[][] topLeft = new double[HASH_SIZE][HASH_SIZE];
        double sum = 0;
        for (int x = 0; x < HASH_SIZE; x++) {
            for (int y = 0; y < HASH_SIZE; y++) {
                topLeft[x][y] = dctData[x][y];
                sum += topLeft[x][y];
            }
        }

        // 5. 计算中位数
        double median = sum / (HASH_SIZE * HASH_SIZE);

        // 6. 生成哈希值（大于中位数为 1，否则为 0）
        StringBuilder hash = new StringBuilder();
        for (int x = 0; x < HASH_SIZE; x++) {
            for (int y = 0; y < HASH_SIZE; y++) {
                hash.append(topLeft[x][y] > median ? '1' : '0');
            }
        }

        return hash.toString();
    }

    /**
     * 缩放图片
     */
    private BufferedImage resize(BufferedImage image, int width, int height) {
        BufferedImage resized = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = resized.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.drawImage(image, 0, 0, width, height, null);
        g.dispose();
        return resized;
    }

    /**
     * 转灰度图
     */
    private BufferedImage toGrayscale(BufferedImage image) {
        BufferedImage gray = new BufferedImage(image.getWidth(), image.getHeight(), BufferedImage.TYPE_BYTE_GRAY);
        ColorConvertOp op = new ColorConvertOp(ColorSpace.getInstance(ColorSpace.CS_GRAY), null);
        op.filter(image, gray);
        return gray;
    }

    /**
     * 简化 DCT（离散余弦变换）
     */
    private double[][] dct(BufferedImage image) {
        int width = image.getWidth();
        int height = image.getHeight();
        double[][] pixels = new double[width][height];

        // 读取像素值
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                pixels[x][y] = new Color(image.getRGB(x, y)).getRed();
            }
        }

        // DCT 变换
        double[][] result = new double[width][height];
        double n = width;

        for (int u = 0; u < width; u++) {
            for (int v = 0; v < height; v++) {
                double sum = 0.0;
                for (int x = 0; x < width; x++) {
                    for (int y = 0; y < height; y++) {
                        sum += Math.cos(((2 * x + 1) * u * Math.PI) / (2 * n))
                                * Math.cos(((2 * y + 1) * v * Math.PI) / (2 * n))
                                * pixels[x][y];
                    }
                }
                double cu = (u == 0) ? 1.0 / Math.sqrt(n) : Math.sqrt(2.0 / n);
                double cv = (v == 0) ? 1.0 / Math.sqrt(n) : Math.sqrt(2.0 / n);
                result[u][v] = sum * cu * cv;
            }
        }

        return result;
    }

    /**
     * 计算两个哈希值的汉明距离（不同位的个数）
     */
    private int hammingDistance(String hash1, String hash2) {
        if (hash1.length() != hash2.length()) {
            return Integer.MAX_VALUE;
        }
        int distance = 0;
        for (int i = 0; i < hash1.length(); i++) {
            if (hash1.charAt(i) != hash2.charAt(i)) {
                distance++;
            }
        }
        return distance;
    }
}
