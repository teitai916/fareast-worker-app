# 远东工友App 对话日志

> 格式说明：点击条目可展开/收起详细内容。

---

## Round 01 — 2026-06-15 15:00

**提问摘要**：调整地盘安全卡片UI，所属公司名称太长导致越界

**AI 回复要点**：
- 分析：三个统计项（工人编号、所属公司、安全分）横向排列，公司名长时溢出
- 改动：
  - value 字号 16px → 14px，label 字号 12px → 11px
  - 添加 TextOverflow.ellipsis 截断
  - Row 布局从 spaceAround 改为 Expanded 包裹
- 文件：worker_home_page.dart

<details><summary>详细信息</summary>

**修改前**：
```
_buildStatItem → value 16px / label 12px / 无溢出处理
Row(mainAxisAlignment: spaceAround) → 内容长了越界
```

**修改后**：
```
_buildStatItem → value 14px / label 11px / overflow: ellipsis
Row(children: [Expanded(...), Expanded(...), Expanded(...)]) → 均分宽度
```
</details>

---

## Round 02 — 2026-06-15 15:05

**提问摘要**：切换地盘标签时页面不刷新，没有初始化事件

**AI 回复要点**：
- 根因：onTap 中只有首页 `i == 0` 时调用了 `_loadData()`
- 修复：改为每次切换都调用 `_loadData()`

<details><summary>详细信息</summary>

**改动**：`worker_home_page.dart` 第136-139行
```dart
// 改前
if (i == 0) _loadData();

// 改后
_loadData();
```
</details>

---

## Round 03 — 2026-06-15 15:08

**提问摘要**：确认执行 Round 01 的地盘安全卡片UI调整

**AI 回复要点**：
- 实际执行了 Round 01 的改动
- 两个具体改动：`_buildStatItem` 字体缩小+溢出截断，Row 改用 Expanded 包裹

---

## Round 04 — 2026-06-15 17:30

**提问摘要**：调整工人首页快捷功能栏，固定一行四个按钮，最多两行，超出显示「更多」

**AI 回复要点**：
- 方案：Warp → Grid（4列），前7个功能直接显示，第8个位置固定「更多」
- 新增 `_QuickActionData` 数据类
- 新增 `_buildQuickActionsGrid()`、`_buildMoreGridItem()`、`_showMoreMenu()`
- 删除旧的 `_buildQuickAction()`

<details><summary>详细信息</summary>

**改动文件**：`worker_home_page.dart`

核心代码结构：
```dart
_QuickActionData(icon, label, enabled, onTap)

_buildQuickActionsGrid(hasSite):
  List<_QuickActionData> actions = [...]
  maxVisible = 7

_showMoreMenu():
  showModalBottomSheet → GridView 展示全部功能
```
</details>

---

## Round 05 — 2026-06-15 17:44

**提问摘要**：如何在公司 GitLab 推送代码

**AI 回复要点**：
- 给出完整 Git 推送步骤：.gitignore → git add → commit → remote add → push

---

## Round 06 — 2026-06-16 11:05

**提问摘要**：明确给出代码上传 GitLab 的操作步骤

**AI 回复要点**：
- 详细步骤（进入目录→配用户→建.gitignore→add→commit→remote→push）
- 403 解决方案：SSH 或 Personal Access Token

---

## Round 07 — 2026-06-16 12:37

**提问摘要**：如何查看代码是否已上传到 GitLab

**AI 回复要点**：
- 两种方式：浏览器访问 repo URL、命令行 git log + git remote -v

---

## Round 08 — 2026-06-16 12:49

**提问摘要**：如何用 Codemagic 云构建 + 公司私有 GitLab

**AI 回复要点**：
- 第一步：推送代码到公司 GitLab
- 第二步：Codemagic 连接私有仓库（SSH Key / Personal Access Token）
- 第三步：配置构建（Flutter App → working directory = frontend）
- 第四步：构建后下载 `.ipa` / `.apk`
- 建议生成 `codemagic.yaml`

---

## Round 09 — 2026-06-16 13:58

**提问摘要**：git push 报 Authentication failed / HTTP Basic Access denied

**AI 回复要点**：
- 方案 A：SSH Key（推荐）
- 方案 B：Personal Access Token
- 给出两种方案的详细命令行步骤

<details><summary>详细信息</summary>

**Push 报错**：
```
remote: HTTP Basic: Access denied. If a password was provided for Git authentication...
```

**SSH 方案**：
1. `ssh-keygen -t ed25519`
2. 公钥添加到 GitLab Preferences → SSH Keys
3. `git remote set-url origin git@git.fefacade.com:...`
</details>

---

## Round 10 — 2026-06-16 14:20

**提问摘要**：git push 报 non-fast-forward rejected

**AI 回复要点**：
- 根因：GitLab 自动生成初始文件导致远程领先本地
- 解决：`git pull origin main --allow-unrelated-histories` 合并后推送

---

## Round 11 — 2026-06-16 14:27

**提问摘要**：上传附件访问 403，如何解决

**AI 回复要点**：
- 根因：Spring Security 拦截了 `/uploads/**`
- 修复方案：
  - SecurityConfig 添加 `requestMatchers("/uploads/**").permitAll()`
  - CORS 配置允许 `10.106.0.*:*` IP 段

<details><summary>详细信息</summary>

**问题**：Http://10.106.0.242:8080/api/v1/uploads/contracts/xxx.pdf → HTTP 403

**两个修复点**：
1. SecurityConfig：添加 `/uploads/**` 放行
2. CORS：允许局域网 IP 访问
</details>

---

## Round 12 — 2026-06-16 14:42

**提问摘要**：配置安全登录，三个月保持登录状态，到期强制登出

**AI 回复要点**：
- 方案 A：JWT 直接延长到 90 天（改一行配置）
- 方案 B：双 Token 机制（24h JWT + 90天 Refresh Token）
- 推荐方案 A（简单，改 application.yml 一行）

<details><summary>详细信息</summary>

**当前配置**：
```yaml
jwt:
  expiration: 86400000      # 24小时
  refresh-expiration: 2592000000  # 30天（未使用）
```

**方案 A**（推荐）：
```yaml
jwt:
  expiration: 7776000000  # 90天
```
无需改前端。
</details>

---

## Round 13 — 2026-06-16 19:45

**提问摘要**：如何接入手机会员短信验证码服务商

**AI 回复要点**：
- 先修复 AuthController Bug：`sendSms()` → `sendVerificationCode()`
- 推荐阿里云短信（支持香港 +852 号码）
- 5 个集成步骤：开通服务 → 添加 SDK 依赖 → 创建配置类 → 修改 application.yml → 修改 SmsServiceImpl

<details><summary>详细信息</summary>

**Bug 发现**：AuthController.sendSms() 调用的是 `smsService.sendSms()`（仅打日志），而非 `smsService.sendVerificationCode()`（生成验证码并存入 Redis）。

**阿里云集成**：
```xml
<dependency>
    <groupId>com.aliyun</groupId>
    <artifactId>dysmsapi20170525</artifactId>
    <version>2.0.24</version>
</dependency>
```
</details>

---

## Round 14 — 2026-06-18 12:30

**提问摘要**：安全培训视频观看 + 更换地盘/公司后重置 + 打卡联动

**AI 回复要点**：
- 方案覆盖前端+后端
- 后端重置：地盘/公司变更后 `resetMandatoryVideos()`
- 前端视频播放：`video_player` + `Chewie`
- 「观看到最后1秒」用 position >= duration - 1 判断

<details><summary>详细信息</summary>

**后端改动**：
1. SiteServiceImpl + ContractorController：批准后重置视频完成状态
2. SafetyService 新增 `resetMandatoryVideos()`

**前端改动**：
1. api_service 新增 `getSafetyVideos()` / `markVideoWatched()`
2. safety_videos_page 重写：真实数据 + Chewie 播放器

**「观看最后一秒」逻辑**：
```
position 监听 → position >= (duration - 1秒)
  → POST /safety/video-watched { videoId, watchedDuration: duration }
  → 后端 completed = true
```
</details>

---

## Round 15 — 2026-06-18 12:36

**提问摘要**：对比 video_player+Chewie / better_player / WebView 三个方案

**AI 回复要点**：
- 可视化对比表（三个方案的优缺点、推荐度）
- 推荐 video_player + Chewie（官方维护、性能好、包体小）

---

## Round 16 — 2026-06-18 12:39

**提问摘要**：确认使用推荐方案，开始安全培训+打卡联动开发

**AI 回复要点**：
- 完成 Round 14 方案的全部实现
- 后端 4 个文件改动 + 前端 2 个文件改动

---

## Round 17 — 2026-06-18 12:50

**提问摘要**：视频上传到哪个目录 + 如何初始化安全视频列表

**AI 回复要点**：
- 视频文件放到 `backend/uploads/videos/`
- 访问路径 `http://10.106.0.242:8080/api/v1/uploads/videos/xxx.mp4`
- 数据库记录：通过管理员 API 或直接 SQL INSERT

---

## Round 18 — 2026-06-18 14:07

**提问摘要**：视频播放报 ExoPlaybackException: Source error

**AI 回复要点**：
- 根因 1：videoUrl 是相对路径，`VideoPlayerController` 需要完整 URL
- 根因 2：Android 9+ 默认禁止明文 HTTP（Cleartext HTTP）
- 修复：拼接完整 URL + AndroidManifest 添加 `usesCleartextTraffic="true"`

<details><summary>详细信息</summary>

**日志关键行**：
```
Cleartext HTTP traffic to 10.106.0.242 not permitted
```

**修复1**（safety_videos_page.dart）：
```dart
final fullUrl = videoUrl.startsWith('http') ? videoUrl : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$videoUrl';
```

**修复2**（AndroidManifest.xml）：
```xml
<application android:usesCleartextTraffic="true" ...>
```
</details>

---

## Round 19 — 2026-06-18 14:10

**提问摘要**：开始修改视频 URL 拼接的代码

**AI 回复要点**：
- 修改 `_initPlayer()` 中视频加载前判断 URL 类型
- 相对路径自动拼接完整地址

---

## Round 20 — 2026-06-18 14:11

**提问摘要**：编译报错 ApiConfig 冲突

**AI 回复要点**：
- 根因：`ApiConfig` 在 `api_config.dart` 和 `api_service.dart` 中都有定义
- 修复：删掉 `api_config.dart` 的 import，使用 `api_service.dart` 中的 `ApiConfig`

---

## Round 21 — 2026-06-18 14:33

**提问摘要**：未看完安全视频时打卡按钮无效化

**AI 回复要点**：
- 新增后端 `GET /safety/completion-status` 端点
- 前端 `_loadData()` 时检查状态，打卡按钮条件改为 `hasSite && _checkInAllowed`

<details><summary>详细信息</summary>

**后端新增端点**：`GET /safety/completion-status` → `{ checkInAllowed: true/false }`

**前端逻辑**：
```
打卡按钮启用 = 已有地盘 (hasSite) AND 必修视频全部完成
```
</details>

---

## Round 22 — 2026-06-18 15:03

**提问摘要**：看完视频后打卡按钮仍不可用，再次进入视频显示未观看

**AI 回复要点**：
- Bug 1：`GET /safety/videos` 没返回 `completed` 字段（没查 WorkerVideoView）
- Bug 2：前端 `.catchError((_) {})` 吞掉 API 错误
- 修复：Controller 加 `@AuthenticationPrincipal`，查表填充 completed；去掉 silent catch

<details><summary>详细信息</summary>

**修改文件**：
1. `SafetyVideo.java` — 添加 `@Transient private Boolean completed`
2. `SafetyController.java` — getVideos 加 `@AuthenticationPrincipal`，查 WorkerVideoView 填充 completed
3. `safety_videos_page.dart` — 去掉 `.catchError`
</details>

---

## Round 23 — 2026-06-18 15:15

**提问摘要**：解释观看完成记录逻辑

**AI 回复要点**：
- 完整讲解表结构（safety_videos + worker_video_views）
- 观看完成的判断条件：watched_duration >= video.duration
- 重置逻辑：变更地盘/公司后 completed = false
- 打卡检查逻辑：countByWorkerIdAndCompletedTrue >= mandatory count

---

## Round 24 — 2026-06-18 15:26

**提问摘要**：Chrome 能播视频但真机报 Source error（已修复问题仍存在）

**AI 回复要点**：
- 发现 moov 元数据在文件尾部，Android ExoPlayer 要求头部
- 用 `qtfaststart` 工具将 moov 移到头部
- 下载 FFmpeg → Python 安装 qtfaststart → 处理 video_01.mp4

<details><summary>详细信息</summary>

**处理记录**：
```
修前：ftyp → mdat(...) → moov (尾部)
修后：ftyp → moov(头部) → mdat(...)
文件大小：5122477 → 5119285 bytes
```

**命令**：`python -m qtfaststart E:/WorkBuddy/.../safety_01.mp4`
</details>

---

## Round 25 — 2026-06-18 16:16

**提问摘要**：真机报 Cleartext HTTP not permitted

**AI 回复要点**：
- Android 9+ 默认禁止 HTTP 明文流量
- 修复：AndroidManifest.xml 加上 `android:usesCleartextTraffic="true"`

---

## Round 26 — 2026-06-18 16:19

**提问摘要**：确认问题已解决，要求记录（问题记录）

**AI 回复要点**：
- 将 5 个播放问题记录到今日日志

---

## Round 27 — 2026-06-18 16:43

**提问摘要**：创建内部工作人员页面（3个需求）

**AI 回复要点**：
- 方案：后端 InternalController + 前端 internal_home_page
- 三个功能：地盘总览、工人搜索扣分锁卡、锁卡列表一键解锁
- 后续扩展：QR 扫码、飞书免密登录

<details><summary>详细信息</summary>

**计划功能**：
1. 查看所有地盘情况（工人安全分、是否出勤）
2. 扫码/按编号搜索工人 → 安全扣分（快捷-1/自定义）、0分自动锁卡
3. 锁卡工人一览 + 解锁

**后端新增端点**：
- `/internal/sites`、`/internal/workers/search`、`/internal/workers/locked`
- `/internal/workers/{id}/deduct`、`/internal/workers/{id}/toggle-lock`
</details>

---

## Round 28 — 2026-06-18 16:55

**提问摘要**：增加锁卡工人一览 + 解锁功能

**AI 回复要点**：
- 更新方案：新增 `GET /internal/workers/locked` 和 `POST .../toggle-lock`
- 三个 Tab 结构

---

## Round 29 — 2026-06-18 16:57

**提问摘要**：搜索方式改为按姓名+公司，去掉按编号搜索

**AI 回复要点**：
- 搜索参数改为 name + companyId
- 方案更新：姓名模糊搜索 + 判头公司下拉筛选

---

## Round 30 — 2026-06-18 17:13

**提问摘要**：锁卡列表合并到工人管理 Tab，中间 Tab 放快捷扫码按钮

**AI 回复要点**：
- 最终方案：2个 Tab（地盘总览、工人管理）+ 右上角扫码
- 锁定列表作为工人管理下的切换视图
- 确认开始开发

---

## Round 31 — 2026-06-18 17:23

**提问摘要**：后端编译报错 `@Slf4j` missing `log` variable

**AI 回复要点**：
- 修复：InternalController 类添加 `@Slf4j` 注解

---

## Round 32 — 2026-06-18 17:31

**提问摘要**：手动创建内部人员数据库账号

**AI 回复要点**：
- 生成 3 条用户 SQL（SITE_MANAGER / PROJECT_MANAGER / SUPER_ADMIN）
- 密码 123456，BCrypt 加密
- 提供完整 INSERT 语句

---

## Round 33 — 2026-06-19 23:07

**提问摘要**：右上角改为「+」号（仿支付宝微信），去掉 QR 和被锁卡按钮，菜单：扫一扫 / 加黑名单

**AI 回复要点**：
- 替换 AppBar actions 为 PopupMenuButton
- 加黑名单仅 SUPER_ADMIN 可见
- 工人卡片增加黑名单按钮

<details><summary>详细信息</summary>

**改动**：
1. `internal_home_page.dart` — 右上角「+」蓝色方块 → PopupMenuButton
2. 添加 `_showScanPlaceholder()` / `_showBlacklistDialog()` / `_addToBlacklist()`
3. `api_service.dart` — 新增 `addBlacklist()` 方法
4. 工人卡片按钮 Row → Wrap，SUPER_ADMIN 多显示「黑名单」按钮
</details>

---

## Round 34 — 2026-06-21 17:23

**提问摘要**：复制工人首页给内部人员，去除更换公司，改为申请加入地盘；可多地盘切换；SITE_MANAGER 审批

**AI 回复要点**：
- 方案设计：新增 staff_sites / staff_site_applications 表
- 自动审批逻辑：有 SITE_MANAGER → 需审批，无 → 自动通过
- SUPER_ADMIN 可切换所有地盘（无需申请）
- 3个 Tab → 2个 Tab（首页+个人中心）
- 地盘名可点击切换

<details><summary>详细信息</summary>

**数据模型**：
```sql
CREATE TABLE staff_sites (
    user_id, site_id, is_current, joined_at
    UNIQUE(user_id, site_id)
);
CREATE TABLE staff_site_applications (
    user_id, site_id, status, reviewed_by, reviewed_at
);
```

**申请流转**：
```
申请 → 查该地盘有 SITE_MANAGER 吗？
  ├── 有 → PENDING → 通知 SITE_MANAGER 审批
  └── 无 → 自动 APPROVED → 加入 staff_sites
SUPER_ADMIN → 跳过申请，直接加入
```

**完整改动**：V14 迁移 + StaffSite 实体 + StaffSiteApplication 实体 + InternalController 扩展
</details>

---

## Round 35 — 2026-06-21 20:19

**提问摘要**：后端编译报错 attendanceRepository 找不到

**AI 回复要点**：
- 移除残留的 `/internal/attendance/daily` 端点
- 清理未使用的 `LocalDate` import

---

## Round 36 — 2026-06-21 20:21

**提问摘要**：前端编译报错 chevron_down 找不到

**AI 回复要点**：
- 修复：`Icons.chevron_down` → `Icons.arrow_drop_down`

---

## Round 37 — 2026-06-21 21:44

**提问摘要**：内部人员页面 `/attendance/daily` 报 403 权限不足

**AI 回复要点**：
- 根因：AttendanceController 限制 `hasRole('WORKER')`
- 修复：内部人员跳过考勤 API 调用（设 todayAtt = null）

---

## Round 38 — 2026-06-22 09:49

**提问摘要**：创建 conversation-log.md 文件，自动记录对话日志，可展开/收起

**AI 回复要点**：
- 创建完整对话日志文件
- 使用 GitHub Flavored Markdown 的 `<details>` 标签实现展开/收起
- 每条记录：轮次、时间、提问摘要、AI 回复要点、可展开详情
- 新增文件 `conversation-log.md`
- 后续每轮对话结束后自动追加新记录

---

## Round 39 — 2026-06-22 11:00

**提问摘要**：分析 403 原因，内部人员保留打卡考勤，建立 profile 表

**AI 回复要点**：
- 发现 3 个 403 原因：/worker/home、/attendance/daily、/attendance/monthly 都限制 WORKER 角色
- Attendance.workerId = WorkerProfile.id（非 User.id），内部人员无法复用
- 方案：新增 staff_profiles 表，简化打卡逻辑（跳过 face/视频/地理围栏检查）
- 后端：StaffProfile 实体 + InternalAttendanceService + InternalController 3个新端点
- 前端：api_service 3个新方法 + 首页恢复打卡按钮 + 考勤卡片

---

## Round 40 — 2026-06-22 12:16

**提问摘要**：加黑名单改为输入工人手机号+平安卡号+附件上传

**AI 回复要点**：
- 新增 `POST /internal/workers/blacklist-by-phone` 端点
- 流程：手机号→查User→查WorkerProfile→标记黑名单→更新平安卡号和附件
- 前端弹窗改造：手机号（必填）+ 平安卡号 + 文件上传 + 原因

<details><summary>详细信息</summary>

**后端新增**：
- `InternalController.java` — 新增 `blacklistByPhone()` 端点
- `api_service.dart` — 新增 `blacklistByPhone()` 方法

**前端**：
- `_showBlacklistDialog()` 重写：`TextField(手机号) + TextField(平安卡) + file_picker(附件) + TextField(原因)`
</details>

---

## Round 41 — 2026-06-22 15:13

**提问摘要**：blacklist_records 表增加独立字段（name/regNum/age/companyId/status），加黑名单同步更新两表

**AI 回复要点**：
- BlacklistRecord 实体新增 5 个字段
- 加黑名单逻辑：先查 blacklist_records（有→更新status，无→新增）→ 设置 worker_profiles.blacklisted=true + card_locked=true
- 锁卡操作只操作 worker_profiles.card_locked，不涉及 blacklist_records

<details><summary>详细信息</summary>

**BlacklistRecord 新增字段**：
| 字段 | 说明 |
|------|------|
| name | 工人姓名 |
| workerRegistrationNum | 工人注册证号码 |
| age | 年龄 |
| companyId | 公司号码 |
| status | true/false |

**加黑名单流程**：
```
findByWorkerId → 有记录？→ 更新 status=true : 新增记录
→ worker_profiles.blacklisted=true
→ worker_profiles.card_locked=true（自动锁卡）
```
</details>

---

## Round 42 — 2026-06-22 15:49

**提问摘要**：内部人员多地盘打卡，A未签退切B地盘时自动签退A

**AI 回复要点**：
- 改为查询当日所有记录（不再查单条）
- 逻辑：同地盘再打卡=签退 / 其他地盘未签退=自动签退 + 新签到 / 无未签退=创建签到
- 移除"今日已完成"限制，允许一天多次打卡

<details><summary>详细信息</summary>

**新打卡流程**：
```
查今日所有记录 → 同地盘有未签退？→ 签退
  → 其他地盘有未签退？→ 自动签退上一个 + 新地盘签到
  → 全部已签退/无记录？→ 新地盘签到
```
</details>

---

## Round 43 — 2026-06-22 15:53

**提问摘要**：今日考勤 UI 需要显示多地盘多条考勤记录，增加日历查询

**AI 回复要点**：
- 方案A（时间轴卡片）+ 日历选择器：每条记录一张子卡片，按时间排列
- 后端 getDailyRecord 改为返回当日所有记录列表 + 每条时长 + 总工时
- 前端重写考勤卡片为时间轴，标题栏增加日期选择按钮

<details><summary>详细信息</summary>

**UI 布局**：
```
考勤記錄  [📅 今日 ▼]             6小時03分
┌─────────────────────────────────┐
│ ✅ 啟德醫院   08:32→12:05 3h33m │
│ 🔵 九龍灣     13:20→進行中     │
└─────────────────────────────────┘
```

**后端返回格式变化**：
```json
{ "records": [...], "recordCount": 2, "totalDuration": "6h03m" }
```
新增 `InternalAttendanceServiceImpl.formatDuration()` 辅助方法。
</details>

---

## Round 44 — 2026-06-23 09:13

**提问摘要**：1. app是否支持离线打卡？2. 当前代码能否满足潮汐式并发？

**AI 回复要点**：
- **离线打卡**：完全不支持。打卡6步中3步依赖网络API（人脸验证、打卡提交、记录刷新），前端无本地考勤数据库，无离线队列机制。
- **潮汐并发**：存在多个隐患 — 重复打卡保护缺失（无UNIQUE约束+无分布式锁）、无限流机制、无异步处理、HikariCP连接池仅20、Redis空跑未被使用。
- 给出 P0-P2 优先级改进建议。

<details><summary>详细信息</summary>

### 离线打卡现状

| 步骤 | 依赖 | 离线能力 |
|------|------|---------|
| 获取地盘ID | API: getWorkerHome() | 🔴 依赖网络 |
| BLE扫描 | 本地蓝牙 | 🟢 可离线 |
| GPS定位 | 本地GPS | 🟢 可离线 |
| 人脸验证 | API: verifyFace() | 🔴 依赖网络 |
| 打卡提交 | API: checkIn() | 🔴 依赖网络 |
| 刷新记录 | API: getDailyAttendance() | 🔴 依赖网络 |

- 前端无本地考勤数据库（sqflite/Hive），仅 shared_preferences 存token
- 无离线队列或"断网暂存、联网后同步"机制

### 潮汐并发隐患

| 风险等级 | 问题 | 详情 |
|---------|------|------|
| 🔴 严重 | 重复打卡保护缺失 | attendances表无 `UNIQUE(worker_id, date)` 约束，并发时存在Read-Check-Write竞态 |
| 🔴 严重 | 无分布式锁 | checkIn 方法 `@Transactional` READ_COMMITTED 下两个并发请求可同时INSERT |
| 🔴 严重 | 无限流机制 | 无Rate Limiter，高峰时所有请求涌入 |
| 🟡 中 | HikariCP 连接池=20 | 100人同时打卡可能连接耗尽 |
| 🟡 中 | 无异步处理 | 所有操作同步阻塞，人脸pHASH阻塞主线程 |
| 🟡 中 | Redis空跑 | `@EnableCaching` 已配置但零处使用 |
| 🟡 中 | 无批量打卡API | 每个工人独立HTTP调用 |

### 建议优先级

| 优先级 | 改进项 | 改动量 |
|--------|--------|--------|
| **P0** | attendances 表加 `UNIQUE(worker_id, date)` 唯一约束 | 1行SQL |
| **P0** | HikariCP 连接池增至 50-100 | 1行配置 |
| **P1** | Redis 缓存 Site/WorkerProfile 热点数据 | 少量代码 |
| **P1** | 限流（令牌桶/滑动窗口） | 少量配置 |
| P2 | 异步处理人脸验证 | 改造量较大 |
| P2 | 离线打卡能力 | 专项改造 |

</details>

---

## Round 45 — 2026-06-23 09:54

**提问摘要**：记录到conversation-log.md，列出三项架构优化与高可用建议，待后续研究

**AI 回复要点**：
- 将分析结果追加到 conversation-log.md
- 确认以下三项建议已记录，待后续研究后处理：

<details><summary>详细信息</summary>

### 建议1：动静分离（图片/文件直传对象存储）

| 当前问题 | 建议方案 |
|---------|---------|
| 人脸照片、平安卡附件、合约附件直接通过 Spring Boot 接收并存储在本地 `uploads/` 目录 | 人脸照片/证件照直接上传至云端对象存储（OSS/COS），后端生成**预签名URL**给前端直传，不经过应用服务器 |
| 频繁的 base64 照片传输大量占用服务器带宽 | 动静分离后：定位文字数据 → 服务器；照片/附件 → OSS/COS 直传 |

**当前状态**：未实现。`FaceVerificationServiceImpl` 接收 base64 图片通过 `@RequestBody` JSON 传输。

### 建议2：防重复提交（接口幂等性）

| 当前问题 | 建议方案 |
|---------|---------|
| APP端可能因网络抖动重复发送打卡请求 | 后端在**应用层**或通过 **Redis** 实现防重机制：对同一 `(userId, date)` 的打卡请求，写入 Redis 幂等键（如 `checkin:lock:{userId}:{date}`，TTL=5分钟），并发请求只有第一个能获取锁 |
| attendances 表缺少 `UNIQUE(worker_id, date)` 约束 | 虽然服务层可以拦截，但数据库层也应加唯一约束作为最后防线 |

**当前状态**：未实现。数据库无唯一约束，服务层无 Redis 锁，存在竞态条件。

### 建议3：异步处理

| 当前问题 | 建议方案 |
|---------|---------|
| 考勤统计、生成报表、人脸比对等**非实时**操作全部同步阻塞主线程 | 引入消息队列（Kafka / RabbitMQ / Redis Stream），打卡后的统计工作异步投递到消费者处理 |
| 高峰时段每个请求串行执行这些计算 | 异步化后：主线程快速返回打卡成功 → 消息队列缓冲异步消费 → 统计/报表后台生成 |

**当前人脸比对流程**（同步）：
```
WorkerController.verifyFace()
  → WorkerServiceImpl.verifyFace()
    → registerFaceBase64()         // 从本地 face-images/ 加载注册图
    → pHash.hash() + hammingDistance()  // CPU计算
    → return { matched, score }
```
整个过程在请求线程中同步执行，高峰期所有请求排队等待。

**当前状态**：未实现。无消息队列依赖，无 `@Async` 注解。

</details>

---

## Round 46 — 2026-06-24 12:14

**提问摘要**：开发内部人员扫一扫安全扣分功能

**AI 回复要点**：
- 扫码工人QR码 → 解析workerNumber → 查询工人信息 → 扣分界面 → 扣分后0分自动锁卡+黑名单
- 后端：新增 `GET /internal/workers/by-number/{workerNumber}` 端点 + 扣分自动黑名单
- 前端：新建 `scan_deduct_page.dart`（mobile_scanner扫码+扣分UI），替换占位符

<details><summary>详细信息</summary>

### 后端改动
- `InternalController.java` — 新增 `GET /internal/workers/by-number/{workerNumber}`（调用 `findByWorkerNumber`）
- `InternalController.java` — `toWorkerMap()` 新增 `blacklisted`
- `InternalController.java` — `/workers/{id}/deduct` 安全分=0时自动写入 `blacklist_records` 表

### 前端改动
- `pubspec.yaml` — 新增 `mobile_scanner: ^6.0.0`
- `scan_deduct_page.dart`（新建）— QR扫描→查API→扣分界面（数字输入+上下箭头+快捷按钮-1/-3/-5/-10）
- `internal_home_page.dart` — `_showScanPlaceholder()` → `_openScanner()` 导航新页面
- `api_service.dart` — 新增 `getWorkerByNumber(workerNumber)`
- `Info.plist` — 新增 `NSCameraUsageDescription`

### 扣分界面布局
```
工人编号/姓名/地盘/公司/现有安全分
扣分输入 [ - 数字 + ]  -1 -3 -5 -10
扣分原因输入
剩余安全分（0分红色预警+确认弹窗）
[确认扣分]
```

</details>

---

## Round 47 — 2026-06-24 14:15

**提问摘要**：1. 安全分显示修正为地盤维度15分制（关联 worker_site_safety_scores 表）2. 扣分UI优化（去+-圈圈，改细小▲▼箭头；去快捷按钮）

**AI 回复要点**：
- **安全分修正**：后端新增强 WorkerSiteSafetyScoreRepository，getWorkerByNumber 返回 siteSafetyScore + siteSafetyTotal；扣分端点同步扣除地盤安全分
- **UI优化**：输入框右侧放置细小 KeyboardArrowUp/Down 图标；删除所有快捷扣分按钮

<details><summary>详细信息</summary>

### 安全分修正（后端）
- `InternalController.java` — 新增 `WorkerSiteSafetyScoreRepository` 注入
- `getWorkerByNumber()` — 查询 `worker_site_safety_scores.findByWorkerIdAndSiteId()` 获取地盤安全分
- 响应新增 `siteSafetyScore`（当前分）和 `siteSafetyTotal`（=15）
- `/workers/{id}/deduct` — 同时扣减地盤安全分，自动锁卡/黑名单判断加入地盤分检查

### 扣分UI优化（前端）
- 去掉 `IconButton(Icons.remove_circle_outline)` 和 `add_circle_outline`
- 改为 `TextFormField.suffixIcon` 中放两个 `GestureDetector` 包裹的微小箭头（16px）
- 删除 `_buildQuickDeduct()` 方法和四个快捷按钮
- 安全分显示改为 `現有安全分: X / 15 分`、`剩餘安全分: X / 15`

</details>

