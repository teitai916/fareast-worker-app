/// 远东工友App - API配置
class ApiConfig {
  // 修改为实际服务器地址
  static const String baseUrl = 'http://10.106.0.242:8080/api/v1';

  // 开发环境 (局域网)
  static const String baseUrlDev = 'http://10.106.0.242:8080/api/v1';

  // API超时配置
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  // API端点
  static const String sendSms = '/auth/send-sms';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String resetPassword = '/auth/reset-password';
  static const String refreshToken = '/auth/refresh';
  static const String feishuLogin = '/auth/feishu-login';

  // Worker
  static const String workerProfile = '/worker/profile';
  static const String workerRegister = '/worker/register';
  static const String workerFaceRegister = '/worker/face-register';
  static const String workerSafetyScore = '/worker/safety-score';
  static const String workerDeductions = '/worker/deductions';

  // Site
  static const String currentSite = '/site/current';
  static const String siteDetail = '/site/detail';
  static const String changeSite = '/site/change';
  static const String cancelChangeSite = '/site/cancel-change';
  static const String historySites = '/site/history';

  // Company
  static const String currentCompany = '/company/current';
  static const String changeCompany = '/company/change';
  static const String cancelChangeCompany = '/company/cancel-change';

  // Attendance
  static const String attendanceCheckIn = '/attendance/check-in';
  static const String attendanceRecords = '/attendance/records';

  // Safety Video
  static const String safetyVideos = '/safety/videos';
  static const String markVideoWatched = '/safety/video-watched';

  // Contractor
  static const String contractorSites = '/contractor/sites';
  static const String contractorSiteWorkers = '/contractor/site-workers';
  static const String contractorWorkerAttendance = '/contractor/worker-attendance';
  static const String contractorAuditList = '/contractor/audit-list';
  static const String contractorApprove = '/contractor/approve';

  // Admin
  static const String adminCompanies = '/admin/companies';
  static const String adminSites = '/admin/sites';
  static const String adminWorkers = '/admin/workers';
  static const String adminBlacklist = '/admin/blacklist';
  static const String adminLockCard = '/admin/lock-card';
  static const String adminUnlockCard = '/admin/unlock-card';
  static const String adminDeductScore = '/admin/deduct-score';
  static const String adminAddToBlacklist = '/admin/add-blacklist';
  static const String adminRemoveFromBlacklist = '/admin/remove-blacklist';

  // Super Admin (后台管理)
  static const String superAdminUsers = '/super-admin/users';
  static const String superAdminCompanies = '/super-admin/companies';
  static const String superAdminSites = '/super-admin/sites';
  static const String superAdminBlacklist = '/super-admin/blacklist';
  static const String superAdminVideos = '/super-admin/videos';
  static const String superAdminAttendance = '/super-admin/attendance';
  static const String superAdminRoles = '/super-admin/roles';
  static const String superAdminPermissions = '/super-admin/permissions';
  static const String superAdminUsersMgmt = '/super-admin/admin-users';
}
