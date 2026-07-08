# =============================================
# 远东工友 App — 后端 Docker 镜像
# 多阶段构建：Maven 编译 → JRE 运行
# 构建命令: docker build -t fareast-backend backend/
# =============================================

# ============ Stage 1: 构建阶段 ============
FROM maven:3.9-eclipse-temurin-17-alpine AS build

WORKDIR /app

# 先复制 pom.xml 并下载依赖（利用 Docker 缓存加速）
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# 再复制源码并构建
COPY src ./src
RUN mvn clean package -DskipTests -B -q

# ============ Stage 2: 运行阶段 ============
FROM eclipse-temurin:17-jre-alpine

# 创建非 root 用户，遵循安全最佳实践
RUN addgroup -g 1000 appgroup \
    && adduser -u 1000 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

# 从构建阶段复制 JAR 文件
COPY --from=build /app/target/*.jar app.jar

# 创建上传目录和日志目录
RUN mkdir -p /app/uploads /app/logs \
    && chown -R appuser:appgroup /app

# 切换到非 root 用户
USER appuser

# 对外暴露 8080 端口
EXPOSE 8080

# 健康检查（依赖 spring-boot-starter-actuator）
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/api/v1/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "app.jar"]
