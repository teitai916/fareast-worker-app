# 远东工友 App — 部署状态交接文档（STATUS）

> 用途：长对话收尾后，新会话读此文档即可接手，无需翻历史。
> 最近更新：2026-07-15

## 1. 生产环境关键信息

| 项 | 值 |
|----|----|
| 服务器 | `10.106.8.165`（内网） |
| SSH 用户 | `fsadmin` |
| 域名 | `fsapp.fefacade.com`（DNS 指向内网 IP） |
| SSL | Let's Encrypt（已生效，TLS 1.3） |
| 项目目录（服务器） | `~/deploy`（compose 根）/ `~/backend`（源码，已打包进镜像） |
| API context-path | `/api/v1` |
| 对外端口 | 80（HTTP→HTTPS 重定向）、443、10443（备用 HTTPS） |
| 健康检查 | `https://fsapp.fefacade.com/api/v1/actuator/health` |

## 2. 容器栈（docker-compose）

`nginx` / `certbot` / `backend` / `postgres:15` / `redis:7`

- backend 端口 `8080` 仅 Docker 内网可达（不映射宿主机），经 nginx 反代。
- postgres `5432`、redis `6379` 当前仍映射到 `0.0.0.0`（见 §6 待办 D）。
- backend 健康探测：`backend:8080/api/v1/actuator/health`（Dockerfile healthcheck）。

## 3. 已生效的修复（截至 2026-07-15）

| # | 问题 | 修复位置 | 状态 |
|---|------|----------|------|
| 1 | Redis 连 localhost 失败 | `backend/.../config/RedisConfig.java`：手动 `LettuceConnectionFactory` 读 `${spring.redis.host:redis}` | ✅ 已重建生效（工人登录正常） |
| 2 | 自签证书 SSL 绕过 | `api_service.dart` 还原为 `http.Client()`；`safety_videos_page.dart` 影片改回 HTTPS；`network_security_config.xml` 已删除 | ✅ 源码已清，iOS ATS 兼容 |
| 3 | 健康检查 401 无返回 | `SecurityConfig.java` 放行 `.requestMatchers("/actuator/**").permitAll()` | ✅ backend 现 `(healthy)` |
| 4 | nginx `/health` 500 | `default.conf` 的 `location /health` proxy_pass 补 `/api/v1` 前缀 | ✅ 仅 HTTPS 服务块（443/10443） |
| 5 | nginx 崩溃循环（证书丢失） | 证书改为随 `deploy/` 包走，放 `deploy/nginx/ssl/`；`.gitignore` 忽略 `*.pem` | ✅ 重部署不再丢证书 |

## 4. 标准重部署流程（务必照此，避免再踩坑）

**本地（Git Bash，项目根目录）：**
```bash
tar -czf fareast-deploy.tar.gz \
  --exclude="backend/uploads" \
  --exclude="backend/logs" \
  --exclude="backend/*.log" \
  --exclude="backend/nul" \
  backend/ deploy/
scp fareast-deploy.tar.gz fsadmin@10.106.8.165:~/
```

**服务器：**
```bash
rm -rf ~/backend ~/deploy
tar xzf ~/fareast-deploy.tar.gz -C ~/
cd ~/deploy
docker compose build --no-cache backend   # SecurityConfig 改了必须重建
docker compose up -d backend
docker compose restart nginx               # 仅配置变更，restart 即可
```

> 注意：`up` 不支持 `--no-cache`，须拆成 `build --no-cache` + `up -d`。
> 证书已在包内，`rm -rf ~/deploy` 重解压也不会丢。

**验证：**
```bash
curl -s https://fsapp.fefacade.com/api/v1/actuator/health   # 期望 {"status":"UP"}
curl -sk https://localhost/health                           # 期望 {"status":"UP"}
docker compose ps | grep -E "backend|nginx"                 # 期望均 Up/healthy
```

## 5. 调试要点（省 token）

- **贴日志先过滤**，只发关键行。例：
  ```bash
  docker compose logs nginx 2>&1 | grep -E "emerg|error" | tail -5
  ```
- `curl http://localhost/health`（80 端口）会 500 —— 因 `/health` 只在 HTTPS 服务块。**正确命令见 §4 验证**。
- 一次性容器跑 `nginx -t` 报 `host not found in upstream "backend"` 是假错误（不在 compose 网络），忽略。
- 后端端口不映射宿主机，`curl localhost:8080` 必 exit 7，属正常。

## 6. 已知待办

- **A. HTTP(80) 服务的 `/health`**：✅ **已修复并部署验证（2026-07-15）**。`default.conf` HTTP server 块 `location /api/` 后已补 `location /health` proxy_pass 到 `backend:8080/api/v1/actuator/health`。**服务器验证**：`curl http://localhost/health` 返回 `{"status":"UP",...}`（含 db/redis 子组件 UP）。
- **D. 安全加固**：✅ **已修复并部署验证（2026-07-15）**。`docker-compose.yml` postgres/redis 端口已綁 `127.0.0.1`（`127.0.0.1:5432:5432` / `127.0.0.1:6379:6379`），不再暴露 `0.0.0.0`。Docker 內網 `postgres`/`redis` 服務名互訪不受影響。⚠️ 外部直連數據庫端口已失效，需經 SSH 隧道（`ssh -L 5432:127.0.0.1:5432 fsadmin@10.106.8.165`）或本機 `psql -h 127.0.0.1` 操作。
  - **決策依據**：企業防火牆已擋 5432/6379（外部不可達）；公司網絡同事建議「不開放這兩個端口」→ 綁 127.0.0.1 與該建議一致，並移除內網網段暴露。`docker compose exec redis redis-cli ping` 回 `(error) NOAUTH` → **redis 已設密碼**，縱深防禦成立。用戶拍板 A、D 均做。
  - **2026-07-15 17:23 例外（用戶拍板）**：因需客戶端直連 postgres 做數據初始化，postgres 端口已**暫時開放**為 `0.0.0.0:5432`（移除 127.0.0.1 綁定）；redis 仍鎖 `127.0.0.1`。初始化完成後**建議鎖回 postgres 至 127.0.0.1**。SSH 隧道方案（用戶試過）因本機端口佔用未成，用戶選擇直接開端口。
  - **服务器验证**：`docker compose ps` 显示 `127.0.0.1:5432->5432` / `127.0.0.1:6379->6379`（已生效）；nginx 仍顯示 `0.0.0.0:80/443/10443` 為**預期正確**（nginx 須對外提供 Web 流量，本次只加固 DB/Redis）。HTTPS 回歸 `curl https://fsapp.fefacade.com/api/v1/actuator/health` 仍 `{"status":"UP"}` 正常。
  - **部署方式**：本次起改用整包打包（`tar czf fareast-deploy.tar.gz --exclude='deploy/.env' deploy/` → scp 整包 → 服務器先 `cp -a deploy deploy.bak.<ts>` 備份 → `tar xzf` 覆蓋），避免逐檔 scp 漏檔。`.env` 排除保留伺服器現役密鑰，證書 `nginx/ssl/*.pem` 隨包走。
- **4G 外网访问**：域名指向内网 IP，外部 4G 无法直连，需 Cloudflare Tunnel 之类方案。（未做，需 Tunnel Token）
- **Flutter Web 前端**：`nginx/html` 目录暂无 `index.html`（SPA fallback 落空），80/443 根路径当前无前端页面。（未做，需 `flutter build web` 产出放 `deploy/nginx/html/`）

## 7. 开发协作规则（用户要求）

- **构建命令由用户执行**，agent 只提供命令与修改建议，不代为打包/构建。
- **代码修改必须先审后做**：先列修改清单经用户同意，再写代码。
- 每次修改后 agent 须列出「修改清单 + 摘要」。
