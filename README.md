# 远东工友 App

> 香港建筑工地工人安全管理平台

## 项目概览

远东工友是一款面向香港建筑行业的工人管理平台，支持 **工人端**、**分判商端**、**平台管理端** 三个角色，涵盖工人注册/准入、安全培训、考勤打卡、地盘/公司管理、黑名单管理、物资申领等核心业务功能。

> 🟢 **本地开发环境已全部就绪（2026-06-05）**
>
> Flutter 3.44.1 ✅ | JDK 17 ✅ JAVA_HOME 已固定 | Maven 3.9.9 ✅
> PostgreSQL 18.4 ✅ 运行中 | Redis 8.8.0 ✅ 运行中 | 数据库 `fareast_worker` ✅ 已创建
>
> 直接运行 `mvn spring-boot:run -Dspring-boot.run.profiles=dev` 即可启动后端 🚀

## 技术栈

| 层次 | 技术 | 说明 |
|------|------|------|
| **移动端** | Flutter 3.44.1 (Dart 3.12.1) | 跨平台（已安装于 `C:\tools\flutter`），一套代码同时上架 iOS App Store + Google Play |
| **后端** | Java 17 + Spring Boot 3.2 | 企业级 REST API（JDK 17 已安装于 `C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot`） |
| **数据库** | PostgreSQL 15+ | 主数据库 |
| **缓存** | Redis 7.x | 验证码缓存、Session 管理 |
| **ORM** | Spring Data JPA + Flyway | 数据库迁移管理 |
| **安全** | Spring Security + JWT | 无状态认证 |
| **文档** | Swagger / OpenAPI 3.0 | API 文档自动生成 |
| **基础设施** | Docker / Docker Compose | 容器化部署 |

## 项目结构

```
远东工友App/
├── frontend/                    # Flutter 移动端
│   ├── lib/
│   │   ├── main.dart            # 应用入口
│   │   ├── app.dart             # 应用配置
│   │   ├── config/
│   │   │   ├── theme.dart       # 主题配置（品牌色/字体/组件样式）
│   │   │   ├── routes.dart      # 路由配置
│   │   │   └── api_config.dart  # API 连接配置
│   │   ├── models/              # 数据模型
│   │   ├── services/            # API 服务层
│   │   │   └── api_service.dart # 后端 API 对接
│   │   ├── pages/
│   │   │   ├── auth/            # 注册登录页面
│   │   │   ├── worker/          # 工人端页面
│   │   │   ├── contractor/      # 分判商端页面
│   │   │   └── admin/           # 平台管理端页面
│   │   └── widgets/             # 通用 UI 组件
│   ├── android/                 # Android 原生配置
│   ├── ios/                     # iOS 原生配置
│   └── pubspec.yaml             # Flutter 依赖
│
├── backend/                     # Spring Boot 后端
│   ├── src/main/java/com/fareast/worker/
│   │   ├── config/              # 配置类
│   │   ├── controller/          # REST 控制器
│   │   ├── security/            # JWT + 安全过滤
│   │   ├── service/             # 业务逻辑层
│   │   │   └── impl/            # 服务实现
│   │   ├── repository/          # 数据访问层
│   │   ├── model/
│   │   │   ├── entity/          # JPA 实体 (14个)
│   │   │   ├── dto/             # 请求/响应 DTO
│   │   │   └── enums/           # 枚举类型
│   │   └── exception/           # 全局异常处理
│   ├── src/main/resources/
│   │   ├── application.yml      # 应用配置
│   │   └── db/migration/        # Flyway 迁移脚本
│   └── pom.xml                  # Maven 依赖
│
└── docs/                        # 项目文档
```

## 功能模块

### App 端

#### 🔐 注册登录
- 手机号 + 验证码注册
- 手机号 + 密码登录
- 忘记密码（验证码重置）
- 每 3 个月强制登出
- 飞书企业版免密登录

#### 👷 工人端
- **首页**：公告、考勤信息、天气提醒、快捷打卡入口
- **工人准入**：资料填写 → 黑名单比对 → 60岁审批 → 安全培训 → 人脸识别登记
- **地盘**：当前地盘信息、打卡、更换地盘（申请/撤销/历史）
- **公司**：当前公司、更换公司
- **考勤**：蓝牙定位/GPS打卡、考勤记录查询、月历出勤统计
- **安全培训**：强制观看影片（看片前限制打卡）、进度追踪
- **我的**：工人编号、安全分、物资申领

#### 🏗️ 分判商端
- **地盘管理**：地盘列表/详情、地盘的工人列表和考勤
- **审核管理**：工人准入审核、地盘更换审核、公司更换审核

#### 🛡️ 平台管理端（安装经理/项目经理）
- 全公司/地盘/工人查看
- 黑名单管理（添加/移除）
- 安全分管理（扣分/记录）
- 锁卡/重开卡

### 后台管理系统

| 模块 | 功能 |
|------|------|
| 用户管理 | 列表、详情、禁用启用 |
| 公司管理 | 增删改查 |
| 地盘管理 | 增删改查 |
| 黑名单管理 | 增删改查 + Excel 导入 |
| 影片管理 | 增删改查 + 生成二维码 |
| 考勤管理 | 增删改查 |
| 角色权限 | 角色管理、权限管理、后台用户管理 |
| 系统配置 | 用户协议编辑、隐私政策编辑 |

## 数据库设计 (14张核心表)

| 表名 | 说明 |
|------|------|
| `users` | 用户表（工人/分判商/管理员） |
| `worker_profiles` | 工人扩展信息（HKID/平安卡/薪酬/人脸/安全分） |
| `companies` | 公司表 |
| `sites` | 地盘表（含坐标和蓝牙信标） |
| `attendances` | 考勤打卡记录 |
| `safety_videos` | 安全培训影片 |
| `worker_video_views` | 工人观看影片记录 |
| `blacklist_records` | 黑名单记录 |
| `safety_deductions` | 安全扣分记录 |
| `site_change_requests` | 地盘更换申请 |
| `company_change_requests` | 公司更换申请 |
| `announcements` | 公告 |
| `system_configs` | 系统配置 |
| `material_requests` | 物资申领 |

## API 接口 (11个控制器)

| 控制器 | 端点前缀 | 权限 |
|--------|----------|------|
| AuthController | `/auth` | 公开 |
| WorkerController | `/worker` | WORKER |
| SiteController | `/site` | WORKER |
| CompanyController | `/company` | WORKER |
| AttendanceController | `/attendance` | WORKER |
| SafetyController | `/safety` | 部分公开 |
| ContractorController | `/contractor` | CONTRACTOR |
| AdminController | `/admin` | SITE_MANAGER/PROJECT_MANAGER |
| SuperAdminController | `/super-admin` | SUPER_ADMIN |
| AnnouncementController | `/announcements` | 认证 |
| MaterialController | `/materials` | 认证 |

## 快速开始

### 前置环境（已安装确认 ✅）

你的本地环境已经满足以下条件：

```bash
# ✅ Flutter SDK 3.44.1
#   路径: C:\tools\flutter
#   Dart SDK: 3.12.1
#   渠道: stable (2026-05-29)
#
# ✅ JDK 17 (Temurin-17.0.12+7) — 🔴 注意：这是 Spring Boot 3.x 必需版本
#   路径: C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot
#   JAVA_HOME 需指向此路径，而非 JDK 8
#
# ✅ Android SDK
#   路径: C:\Users\duowei.zheng\AppData\Local\Android\Sdk
#   API 35 / build-tools 35.0.0
#
# ✅ PostgreSQL 18.4
#   路径: C:\Program Files\PostgreSQL\18
#   端口: 5432 (已启动，接受连接)
#   用户名/密码: postgres / 安装时设置的密码
#   数据库 fareast_worker: ✅ 已创建
#   psql: "C:\Program Files\PostgreSQL\18\bin\psql" -U postgres -d fareast_worker
#
# ✅ Maven 3.9.9
#   路径: C:\tool\apache-maven-3.9.9
#   mvn 命令: C:\tool\apache-maven-3.9.9\bin\mvn
#
# ✅ Redis 8.8.0
#   路径: C:\tools\redis
#   服务状态: 🟢 已启动 (redis-cli ping → PONG)
#   默认端口: 6379
```

> **✅ JAVA_HOME 已配置**
> 系统中同时安装了 JDK 8 和 JDK 17。
> `JAVA_HOME` 已永久设置为：
> ```
> C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot
> ```
> 打开新终端后可用 `echo %JAVA_HOME%` 确认。

### 启动后端

```bash
cd backend

# 1. 确认 PostgreSQL 和 Redis 已运行
"C:\Program Files\PostgreSQL\18\bin\pg_isready"   # 应输出: accepting connections
C:\tools\redis\redis-cli ping                     # 应输出: PONG

# 2. 确认 JAVA_HOME 已设置
echo %JAVA_HOME%
# 应输出: C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot

# 3. 启动后端 (开发模式，首次会自动建表)
mvn spring-boot:run -Dspring-boot.run.profiles=dev
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### 启动前端

```bash
cd frontend

# 0. 确认 Flutter SDK 在 PATH 中
#    如果 flutter 命令找不到，手动添加：
#    set PATH=C:\tools\flutter\bin;%PATH%

# 1. 检查 Flutter 环境
flutter doctor

# 2. 安装依赖
flutter pub get

# 3. 配置 API 地址
#    修改 lib/config/api_config.dart 中的 baseUrl
#    默认: http://localhost:8080/api/v1

# 4. 运行（选择 Android 模拟器或真机）
flutter run
```

### Docker Compose 部署

```bash
# 一键启动所有服务
docker-compose up -d
```

## 上架准备

### iOS App Store

1. 准备 Apple Developer 账号 ($99/年)
2. 在 frontend/ios/ 中配置 App ID、Bundle Identifier
3. 准备 App 图标、截图（香港繁体中文）
4. 填写隐私政策（需包含 HKID 收集说明）
5. 使用 Xcode Archive → Upload → TestFlight → App Store

### Google Play

1. 准备 Google Play Developer 账号 ($25 一次性)
2. 在 frontend/android/ 中配置应用签名
3. 准备 App 图标、截图、宣传图
4. 完成 Google Play 隐私政策填写
5. 使用 flutter build appbundle → 上传至 Google Play Console
6. 选择发布地区：香港为主要市场

## 第三方服务集成

| 服务 | 用途 | 配置位置 |
|------|------|----------|
| 阿里云短信 | 发送验证码 | `application.yml` |
| 百度人脸识别 | 人脸登记 | `application.yml` |
| 飞书开放平台 | 免密登录 | `application.yml` |
| 高德地图/Google Maps | 地图定位 | Flutter 端 |

## 版本历史

- **v1.0.0** (2026-06) 初始版本
  - 注册登录、工人准入、安全培训、考勤打卡
  - 地盘/公司管理、黑名单管理、分判商/管理端
  - 后台管理系统完整 CRUD
  - App Store + Google Play 上架配置
