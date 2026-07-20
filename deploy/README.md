# 远东工友 App — Docker 部署指南

## 架构概览

```
                     ┌─────────────────────────────────────┐
    客户端             │              Docker 环境               │
  ┌───────────┐       │  ┌───────────────────────────────┐  │
  │ Flutter   │ HTTPS │  │  Nginx                        │  │
  │ App       │───────▶│  │  :80 (→HTTPS)                │  │
  │ (Android) │       │  │  :443 / :10443 (TLS)          │  │
  ├───────────┤       │  │                               │  │
  │ 浏览器     │ HTTP  │  │  /         → Flutter Web SPA  │  │
  │ (内网测试) │──────▶│  │  /api/     → 后端代理          │  │
  └───────────┘       │  │  /ws/      → WebSocket        │  │
                      │  └──────────┬────────────────────┘  │
                      │             │ (内部网络 fareast-net) │
                      │  ┌──────────▼────────────────────┐  │
                      │  │  Backend :8080                │  │
                      │  │  Spring Boot 3.2 / Java 17    │  │
                      │  └───┬─────────────┬─────────────┘  │
                      │      │             │                │
                      │  ┌───▼──────┐ ┌───▼──────┐         │
                      │  │PostgreSQL│ │  Redis    │         │
                      │  │ :5432    │ │  :6379    │         │
                      │  └──────────┘ └──────────┘         │
                      │                                     │
                      │  ┌──────────────────────────────┐  │
                      │  │  Certbot (SSL证书自动续期)    │  │
                      │  └──────────────────────────────┘  │
                      └─────────────────────────────────────┘
```

### 5 个 Docker 容器

| 容器 | 镜像 | 对公端口 | 用途 |
|------|------|----------|------|
| **nginx** | nginx:1.27-alpine | 80, 443, **10443** | TLS 终止 + 反向代理 + Flutter Web 托管 |
| **certbot** | certbot/certbot | — | Let's Encrypt 自动续期（每 12h） |
| **backend** | fareast-backend (自建) | — (仅内网) | Spring Boot REST API |
| **postgres** | postgres:15-alpine | 5432 | 主数据库 |
| **redis** | redis:7-alpine | 6379 | 缓存 + 短信验证码 |

### Nginx 路由表

| 路径 | HTTP (80) | HTTPS (443/10443) | 说明 |
|------|-----------|-------------------|------|
| `/` | Flutter Web 前端 | Flutter Web 前端 | SPA fallback → `index.html` |
| `/api/` | 代理到 backend | 代理到 backend | REST API |
| `/ws/` | — | WebSocket 代理 | 实时通信 |
| `/uploads/` | — | 代理 + 7d 缓存 | 文件上传 |
| `/health` | — | 健康检查代理 | 跳过日志 |
| `/.well-known/` | ACME 验证 | ACME 验证 | Let's Encrypt |

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
# 重新构建镜像并重启（复用构建缓存，速度快）
docker compose up -d --build backend
```

> ⚠️ **强制全量重建（不使用缓存）**：`--no-cache` 是 `docker compose build` 的参数，
> **`docker compose up` 不支持该参数**。不能写成 `docker compose up -d --build --no-cache backend`
> （会报 `unknown flag: --no-cache`）。正确做法是先 build 再 up：
>
> ```bash
> docker compose build --no-cache backend
> docker compose up -d backend
> ```
>
> 适用场景：源码/配置改动后镜像层疑似被缓存（例如 RedisConfig 等被回滚的旧代码未生效），
> 用 `--no-cache` 确保从头构建。

### 重新部署（代码/配置更新）

> **证书随包走，永不丢失**：真实 Let's Encrypt 证书（`fullchain.pem`/`privkey.pem`）
> 已放在 `deploy/nginx/ssl/`，随 `deploy/` 一起打包到服务器。因此重部署可以放心
> `rm -rf ~/deploy` 后重新解压，证书不会丢。证书私钥已在 `.gitignore` 中忽略，
> 不会提交到 Git（仅保留在本地磁盘供打包）。
> 若需更新证书：替换 `deploy/nginx/ssl/` 下两个文件，重新打包部署即可。

**本地打包（排除上传/日志大文件，证书已包含在 deploy/ 内）：**

```bash
cd /path/to/fareast-worker-app
tar -czf fareast-deploy.tar.gz \
  --exclude="backend/uploads" \
  --exclude="backend/logs" \
  --exclude="backend/*.log" \
  --exclude="backend/nul" \
  backend/ deploy/
scp fareast-deploy.tar.gz user@server-ip:~/
```

**服务器（可安全清空后重解压，证书随包恢复）：**

```bash
rm -rf ~/backend ~/deploy
tar xzf ~/fareast-deploy.tar.gz -C ~/
cd ~/deploy
docker compose build --no-cache backend
docker compose up -d backend
docker compose restart nginx
```

> 验证：`curl -s https://fsapp.fefacade.com/api/v1/actuator/health` 应返回 `{"status":"UP"}`，
> 且 `docker compose ps` 中 nginx 为 `Up`（非 Restarting）。

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

### 生产构建（Google Play App Bundle）

```bash
cd frontend
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://fsapp.fefacade.com/api/v1
```

产物：`build/app/outputs/bundle/release/app-release.aab`

### 生产构建（直接安装 APK）

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://fsapp.fefacade.com/api/v1 \
  --target-platform android-arm64
```

### Flutter Web 构建（内网测试用）

```bash
flutter build web \
  --dart-define=API_BASE_URL=http://10.106.8.165/api/v1
```

产物 `build/web/` 复制到 `deploy/nginx/html/`，重启 Nginx 后即可通过浏览器访问。

### 内网测试 APK（无需 SSL 证书）

生产环境已部署有效的 Let's Encrypt 证书（`fsapp.fefacade.com`），`api_service.dart` 现使用标准
`http.Client()`，依赖系统/设备可信证书链，**无需任何自签证书绕过**。

> 早期版本曾为自签证书在 `api_service.dart` 中使用 `IOClient` + `badCertificateCallback` 临时绕过，
> 该方案已于证书上线后移除。如再次看到此回调，说明代码被回滚，需还原为 `http.Client()`。
> 本地开发走 `http://localhost:8080` 同样无需绕过（明文 HTTP 不受证书校验影响）。

---

## 开发调试

### SMS 验证码查看

验证码通过 `log.warn` 输出到后端日志：

```bash
# 发送验证码
curl -k https://localhost/api/v1/auth/send-sms \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000011"}'

# 查看验证码（或在 docker compose logs -f backend 中观察）
docker compose logs backend --tail=10 | grep "短信验证码"
```

> 验证码 5 分钟有效，验证后自动从 Redis 删除。

### 重置用户密码

```bash
# 生成 BCrypt 哈希（需 Python bcrypt）
HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'新密码', bcrypt.gensalt(rounds=10)).decode())")

# 更新数据库
docker compose exec postgres psql -U fareast -d fareast_worker \
  -c "UPDATE users SET password='$HASH' WHERE phone='手机号';"
```

### API 测试面板

浏览器打开 `http://10.106.8.165/`（HTTP）或 `https://fsapp.fefacade.com/`（HTTPS）可直接使用内置的 API 测试面板。

---

## 端口说明

| 端口 | 协议 | 用途 | 外部访问 |
|------|------|------|----------|
| 80 | HTTP | Flutter Web + API（内网测试） | ✅ |
| 443 | HTTPS | TLS 全功能 | ✅ |
| 10443 | HTTPS | 备用 TLS | ✅ |
| 5432 | TCP | PostgreSQL | ⚠️ 限制 |
| 6379 | TCP | Redis | ⚠️ 限制 |

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
├── docker-compose.yml         # 容器编排（五服务 + 网络 + 卷）
├── .env                        # 环境变量（敏感，已 gitignore）
├── .env.example                # 环境变量模板
├── init-scripts/
│   └── 01-init-extensions.sql  # 数据库扩展初始化
├── nginx/
│   ├── nginx.conf              # Nginx 主配置
│   ├── default.conf             # 站点配置（路由 + TLS + 多端口）
│   ├── ssl/                     # SSL 证书目录
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   └── html/                    # Flutter Web 前端 + 测试页
│       └── index.html           # API 测试面板
├── certbot/
│   └── init-letsencrypt.sh     # Let's Encrypt 初始化脚本
└── README.md                   # 本文档

backend/
├── Dockerfile                   # 多阶段构建（Maven → JRE）
├── .dockerignore
├── pom.xml
└── src/

frontend/
├── lib/
│   ├── config/api_config.dart   # API 地址配置
│   └── services/api_service.dart # HTTP 客户端（标准 http.Client，依赖可信证书链）
└── android/
    └── app/src/main/
        └── AndroidManifest.xml   # Android 清单配置
```
