# 远东工友 App — Docker 部署指南

## 架构概览

```
                     ┌──────────────────────────────┐
    手机端           │           Docker 环境            │
  ┌───────────┐      │  ┌─────────────────────────┐  │
  │ Flutter   │ HTTPS│  │  Nginx :443 (TLS终止)   │  │
  │ iOS/Android│─────▶│  │  反向代理 + 安全头       │  │
  └───────────┘      │  └──────────┬──────────────┘  │
                     │             │ (内网)            │
                     │  ┌──────────▼──────────────┐  │
                     │  │  Backend :8080          │  │
                     │  │  Spring Boot            │  │
                     │  └───┬─────────┬───────────┘  │
                     │      │         │               │
                     │  ┌───▼──┐ ┌───▼───┐           │
                     │  │ PG   │ │ Redis  │           │
                     │  │ :5432│ │ :6379  │           │
                     │  └──────┘ └───────┘           │
                     └──────────────────────────────┘
```

5 个 Docker 容器：`nginx` + `certbot` + `backend` + `postgres:15` + `redis:7`

- **Nginx**: 唯一对外端口（80/443），TLS 终止，反向代理后端
- **Certbot**: 自动续期 Let's Encrypt 证书（每 12 小时检查）
- **Backend**: 仅内网暴露，不直接对外

---

## 前置条件

| 条件 | 版本要求 | 检查命令 |
|------|---------|---------|
| Docker Engine | ≥ 24.0 | `docker --version` |
| Docker Compose | V2（docker compose） | `docker compose version` |
| 可用磁盘 | ≥ 10GB | `df -h` |
| 可用内存 | ≥ 4GB（推荐 8GB） | `free -h` |

### 镜像加速（中国大陆服务器推荐）

```bash
# 编辑 /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}
# 重启 Docker: systemctl restart docker
```

---

## 快速启动

### 1. 准备服务器

```bash
# 将项目拷贝到服务器（假设放到 /opt/fareast）
scp -r backend/ deploy/ user@server-ip:/opt/fareast/

# 进入部署目录
cd /opt/fareast/deploy
```

### 2. 配置环境变量

```bash
# 基于模板创建
cp .env.example .env

# 编辑 .env，至少修改以下三项:
#   - POSTGRES_PASSWORD  （数据库密码，≥16位）
#   - JWT_SECRET         （运行 openssl rand -base64 64 生成）
#   - REDIS_PASSWORD     （Redis 密码）
vim .env
```

### 3. 配置 HTTPS（首次部署）

```bash
# 启动 Nginx（使用自签名占位证书，仅用于 Let's Encrypt 验证）
docker compose up -d nginx

# 运行初始化脚本，生成占位证书并输出 certbot 命令
cd certbot && chmod +x init-letsencrypt.sh && ./init-letsencrypt.sh

# 获取 Let's Encrypt 正式证书（替换 EMAIL）
docker compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d fsapp.fefacade.com \
  --email your-email@example.com \
  --agree-tos --no-eff-email

# 证书获取成功后，需要链接到 Nginx 读取路径
# certbot 会将证书存到 /etc/letsencrypt/live/fsapp.fefacade.com/
# 脚本已自动挂载到 ./nginx/ssl/
# 如果证书未出现在 nginx/ssl/，手动复制：
#   cp /etc/letsencrypt/live/fsapp.fefacade.com/fullchain.pem nginx/ssl/
#   cp /etc/letsencrypt/live/fsapp.fefacade.com/privkey.pem nginx/ssl/

# 重启 Nginx 加载正式证书
docker compose restart nginx
```

### 4. 启动所有服务

```bash
# 构建并启动（首次需要 Maven 下载依赖，约 3-5 分钟）
docker compose up -d --build

# 查看启动状态
docker compose ps

# 查看后端日志
docker compose logs -f backend
```

### 5. 验证服务

```bash
# HTTP → 应返回 301 重定向
curl -I http://fsapp.fefacade.com

# HTTPS 健康检查
curl https://fsapp.fefacade.com/actuator/health

# 预期响应: {"status":"UP"}
```

---

## 常用操作

### 查看日志

```bash
# 所有服务
docker compose logs -f

# 只查看后端
docker compose logs -f backend

# 最近 100 行
docker compose logs --tail=100 backend
```

### 重启服务

```bash
# 重启单服务
docker compose restart backend

# 全部重启
docker compose restart

# 停止并删除容器（数据卷保留）
docker compose down

# 停止并删除容器+数据（⚠️ 数据库将被清空）
docker compose down -v
```

### 更新后端

```bash
# 重新构建镜像并重启
docker compose up -d --build backend

# 如果只修改了代码（未改依赖），跳过构建缓存更快
docker compose up -d --build --no-cache backend
```

---

## 数据管理

### 数据库备份

```bash
# 备份数据库到文件
docker compose exec postgres pg_dump \
  -U fareast fareast_worker > backup_$(date +%Y%m%d_%H%M%S).sql

# 恢复数据库
docker compose exec -T postgres psql \
  -U fareast fareast_worker < backup.sql
```

### 上传文件备份

```bash
# 备份上传目录
tar -czf uploads_backup_$(date +%Y%m%d).tar.gz \
  $(docker volume inspect fareast-uploads --format '{{.Mountpoint}}')

# 恢复上传文件
tar -xzf uploads_backup_20250629.tar.gz -C /path/to/restore
```

### 数据卷信息

| 卷名称 | 内容 | 路径 |
|--------|------|------|
| `fareast-pgdata` | PostgreSQL 数据 | `/var/lib/docker/volumes/` |
| `fareast-redis-data` | Redis AOF/RDB | `/var/lib/docker/volumes/` |
| `fareast-uploads` | 打卡照片、附件 | `/var/lib/docker/volumes/` |
| `fareast-logs` | 应用日志 | `/var/lib/docker/volumes/` |

---

## Flutter App 配置

后端部署完成后，修改 Flutter 的 API 地址：

1. 打开 `frontend/lib/config/api_config.dart`
2. 将 `baseUrlProd` 或 `defaultValue` 改为服务器地址：

```dart
// 方案 A: 修改常量
static const String baseUrlProd = 'https://fsapp.fefacade.com/api/v1';

// 方案 B: 编译时注入（推荐）
flutter build apk --release \
  --dart-define=API_BASE_URL=https://fsapp.fefacade.com/api/v1
```

---

## 安全加固

### 已内置的安全措施

| 措施 | 说明 |
|------|------|
| HTTPS/TLS 1.2+ | Nginx 反向代理，Mozilla Intermediate 加密套件 |
| HSTS | `max-age=63072000` 强制浏览器使用 HTTPS |
| 安全响应头 | X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy |
| 证书自动续期 | Certbot 每 12 小时检查，证书到期前自动续期 |
| 后端不对外暴露 | Backend 仅通过内部网络通信 |
| 版本隐藏 | `server_tokens off` 隐藏 Nginx 版本号 |
| 隐藏文件拒绝 | `location ~ /\.` 拒绝访问配置文件 |

### 防火墙规则（服务器端）

```bash
# 只开放 HTTP/HTTPS 端口
ufw allow 80/tcp
ufw allow 443/tcp

# 禁止数据库端口对外
ufw deny 5432/tcp
ufw deny 6379/tcp
ufw enable
```

---

## 数据库定期备份（Cron）

```bash
# 每天凌晨 3 点备份
0 3 * * * docker compose -f /opt/fareast/deploy/docker-compose.yml exec -T postgres pg_dump -U fareast fareast_worker > /opt/backups/fareast_$(date +\%Y\%m\%d).sql
```

---

## 故障排查

### 后端启动失败

```bash
# 查看详细日志
docker compose logs backend --tail=50

# 常见原因:
# 1. 数据库连接失败 → 检查 postgres 是否 healthy
# 2. JWT_SECRET 未设置 → 检查 .env 文件
# 3. Flyway 迁移冲突 → 检查 migration 版本号是否冲突
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 服务状态
docker compose exec postgres pg_isready

# 手动连接测试
docker compose exec postgres psql -U fareast -d fareast_worker
```

### 内存不足

```bash
# 查看容器资源使用
docker stats fareast-backend fareast-postgres fareast-redis

# 如需要，调整 docker-compose.yml 中的 deploy.resources.limits
```

---

## CI/CD 接入预留

项目结构已为 CI/CD 准备好：

```yaml
# 示例: .github/workflows/deploy.yml
# 1. Checkout 代码
# 2. 通过 SCP/rsync 将 backend/ + deploy/ 传输到服务器
# 3. SSH 执行 docker compose up -d --build
```

---

## 文件清单

```
deploy/
├── docker-compose.yml    # 容器编排（五服务 + 网络 + 卷）
├── .env                   # 环境变量（敏感，已 gitignore）
├── .env.example           # 环境变量模板（可提交 Git）
├── init-scripts/
│   └── 01-init-extensions.sql  # 数据库扩展初始化
├── nginx/
│   ├── nginx.conf         # Nginx 主配置
│   ├── default.conf       # 站点配置（反向代理 + TLS）
│   └── ssl/
│       └── .gitkeep       # 证书占位目录
├── certbot/
│   └── init-letsencrypt.sh # Let's Encrypt 初始化脚本
└── README.md              # 本文档
```
