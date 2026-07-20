package com.fareast.worker.controller;

import com.fareast.worker.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@RestController
@RequestMapping("/upload")
public class UploadController {

    @Value("${file.upload-dir}")
    private String uploadDir;

    /** 允许上传的文件扩展名 */
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "pdf");

    /** 允许的 MIME 类型（防扩展名伪造） */
    private static final Map<String, String> ALLOWED_MIME_TYPES = Map.of(
        "jpg", "image/jpeg",
        "jpeg", "image/jpeg",
        "png", "image/png",
        "pdf", "application/pdf"
    );

    /**
     * 测试端点 - 不需要文件上传
     */
    @GetMapping("/test")
    public ResponseEntity<?> test() {
        Map<String, Object> data = new HashMap<>();
        data.put("message", "Upload endpoint is working!");
        data.put("timestamp", System.currentTimeMillis());
        
        Map<String, Object> result = new HashMap<>();
        result.put("code", 200);
        result.put("message", "success");
        result.put("data", data);
        
        return ResponseEntity.ok(result);
    }

    /**
     * 上传文件
     * POST /api/v1/upload
     * Body: multipart/form-data
     *   - file: 文件内容
     *   - folder: 子目录（可选，如 "contracts"）
     */
    @PostMapping
    public ResponseEntity<?> upload(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "folder", defaultValue = "uploads") String folder,
            HttpServletRequest request) {

        if (file.isEmpty()) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "文件不能为空");
            return ResponseEntity.badRequest().body(error);
        }

        // 文件类型白名单校验
        String originalFilename = file.getOriginalFilename();
        String ext = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            ext = originalFilename.substring(originalFilename.lastIndexOf(".") + 1).toLowerCase();
        }
        if (ext.isEmpty() || !ALLOWED_EXTENSIONS.contains(ext)) {
            throw new BusinessException(400, "不支持的文件格式，仅允许上传 PDF、JPG、PNG 文件");
        }
        String expectedMime = ALLOWED_MIME_TYPES.get(ext);
        String actualMime = file.getContentType();
        // 允许 application/octet-stream（泛型二进制，常见于 HTTP 客户端上传）
        if (actualMime != null && !actualMime.isEmpty()
                && !expectedMime.equalsIgnoreCase(actualMime)
                && !"application/octet-stream".equalsIgnoreCase(actualMime)) {
            throw new BusinessException(400, "文件内容与扩展名不匹配，仅允许上传 PDF、JPG、PNG 文件");
        }

        try {
            // 1. 确保上传目录存在
            Path uploadPath = Paths.get(uploadDir, folder);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            // 2. 生成唯一文件名（保留原始文件名）
            String extension = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                extension = originalFilename.substring(originalFilename.lastIndexOf("."));
            }
            // 文件名格式：uuid_原始文件名，便于识别
            String safeFilename = originalFilename != null ? originalFilename.replaceAll("[^\\u4e00-\\u9fa5a-zA-Z0-9._-]", "_") : "file";
            String uniqueFilename = UUID.randomUUID().toString() + "_" + safeFilename;

            // 3. 保存文件 - 使用 getBytes() 而不是 transferTo()
            Path filePath = uploadPath.resolve(uniqueFilename);
            Files.write(filePath, file.getBytes());

            // 4. 构造可访问的 URL（包含 context-path）
            // 例如：http://localhost:8080/api/v1/uploads/contracts/xxx.pdf
            String contextPath = request.getContextPath();
            String fileUrl = request.getScheme() + "://"
                    + request.getServerName() + ":"
                    + request.getServerPort()
                    + contextPath + "/uploads/" + folder + "/" + uniqueFilename;

            // 5. 返回结果（格式与前端 uploadFile() 匹配）
            Map<String, Object> data = new HashMap<>();
            data.put("url", fileUrl);
            data.put("filename", originalFilename);
            data.put("size", file.getSize());

            Map<String, Object> result = new HashMap<>();
            result.put("code", 200);
            result.put("message", "上传成功");
            result.put("data", data);

            return ResponseEntity.ok(result);

        } catch (IOException e) {
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "文件上传失败：" + e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }
}
