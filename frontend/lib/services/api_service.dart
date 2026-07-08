import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fareast_worker_app/models/user.dart';

/// API 基礎配置
class ApiConfig {
  /// 从 --dart-define=API_BASE_URL=xxx 读取，默认使用测试环境
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.106.0.242:8080/api/v1',
  );

  static const String baseUrlDev = 'http://10.106.0.242:8080/api/v1';
  static const String baseUrlProd = 'https://fsapp.fefacade.com/api/v1';
  static const bool mockMode = false;

  static Map<String, String> headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

/// 全局 Token 管理
class TokenManager {
  static String? _token;
  static User? _currentUser;
  static const _secureStorage = FlutterSecureStorage();

  static String? get token => _token;
  static User? get currentUser => _currentUser;

  static Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      await _secureStorage.write(key: 'auth_token', value: token);
    } else {
      await _secureStorage.delete(key: 'auth_token');
    }
  }

  static Future<void> setUser(User? user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_name', user.name ?? '');
      await prefs.setString('user_phone', user.phone);
      await prefs.setString('user_role', user.role);
    } else {
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_phone');
      await prefs.remove('user_role');
    }
  }

  static Future<void> loadFromStorage() async {
    _token = await _secureStorage.read(key: 'auth_token');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      _currentUser = User(
        id: userId,
        phone: prefs.getString('user_phone') ?? '',
        name: prefs.getString('user_name'),
        role: prefs.getString('user_role') ?? 'WORKER',
        status: 'ACTIVE',
      );
    }
  }

  static Future<void> clear() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_role');
  }
}

/// API 服務
class ApiService {
  final http.Client _client = http.Client();

  String get baseUrl => ApiConfig.baseUrl;
  String? get token => TokenManager.token;

  // ===== Auth APIs =====

  /// 發送短信驗證碼
  Future<void> sendSms(String phone) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/send-sms'),
      headers: ApiConfig.headers(),
      body: jsonEncode({'phone': phone}),
    );
    _handleError(resp);
  }

  /// 登入（返回 User + 保存 Token）
  Future<User> login(String phone, String password) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 800));
      return User(
        id: 1, phone: phone, name: '王大明',
        role: 'WORKER', status: 'ACTIVE',
        token: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: ApiConfig.headers(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    // Backend returns {user: {...}, token: '...'} wrapped in data
    final userData = data['user'] as Map<String, dynamic>;
    final user = User.fromJson(userData);
    final authToken = data['token'] as String;
    await TokenManager.setToken(authToken);
    await TokenManager.setUser(user);
    return user;
  }

  /// 獲取當前登入用戶信息（通用，支持所有角色）
  Future<User> authMe() async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return User(id: 1, phone: '13800000001', name: 'Test', role: 'WORKER', status: 'ACTIVE');
    }
    final currentToken = TokenManager.token;
    if (currentToken == null || currentToken.isEmpty) {
      throw Exception('未登入：token 為空，請重新登入');
    }
    final resp = await _client.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: ApiConfig.headers(token: currentToken),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return User.fromJson(data);
  }

  /// 獲取公司列表（註冊判頭時選擇所屬公司用）
  Future<List<dynamic>> getCompanies() async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [
        {'id': 1, 'name': '遠東建築工程有限公司', 'contactPerson': '陳經理'},
        {'id': 2, 'name': '宏達工程有限公司', 'contactPerson': '李經理'},
        {'id': 3, 'name': '建輝工程有限公司', 'contactPerson': '王經理'},
      ];
    }
    // 此接口已改为公开，不加 token 也能访问（用于注册时选择公司）
    final resp = await _client.get(
      Uri.parse('$baseUrl/company/contractor-list'),
      headers: {'Content-Type': 'application/json'},
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List<dynamic>;
  }

  /// 註冊（工人/判頭通用）
  Future<User> register({
    required String phone,
    required String password,
    required String code,
    required String chineseName,
    required String englishName,
    String role = 'WORKER',
    int? companyId,
    String? birthDate,
    String countryCode = '+852',
  }) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return User(id: 1, phone: phone, name: chineseName, role: role, status: 'ACTIVE');
    }
    final body = <String, dynamic>{
      'phone': phone,
      'password': password,
      'verificationCode': code,
      'chineseName': chineseName,
      'englishName': englishName,
      'role': role,
      'countryCode': countryCode,
    };
    if (companyId != null) body['companyId'] = companyId;
    if (birthDate != null) body['birthDate'] = birthDate;
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: ApiConfig.headers(),
      body: jsonEncode(body),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    // Backend returns {user: {...}, token: '...'} wrapped in data
    final userData = data['user'] as Map<String, dynamic>;
    final user = User.fromJson(userData);
    final authToken = data['token'] as String;
    await TokenManager.setToken(authToken);
    await TokenManager.setUser(user);
    return user;
  }

  /// 重設密碼
  Future<void> resetPassword(String phone, String code, String newPassword) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: ApiConfig.headers(),
      body: jsonEncode({
        'phone': phone, 'verificationCode': code, 'newPassword': newPassword,
      }),
    );
    _handleError(resp);
  }

  /// 登出
  Future<void> logout() async {
    await TokenManager.clear();
  }

  // ===== Worker Home API =====

  /// 工人首頁數據（包含地盤狀態）
  Future<Map<String, dynamic>> getWorkerHome() async {
    if (ApiConfig.mockMode) {
      return {
        'profile': {
          'id': 1, 'userId': 1, 'workerNumber': 'YW20250605-001',
          'faceRegistered': true, 'cardLocked': false,
          'blacklisted': false, 'currentSiteId': null,
        },
        'currentSite': null,
        'hasPendingApplication': false,
        'pendingApplication': null,
        'availableSites': [
          {'id': 1, 'name': '九龍灣宏照道地盤', 'companyId': 1, 'address': '九龍灣', 'managerName': '陳先生'},
          {'id': 2, 'name': '荃灣海盛路地盤', 'companyId': 1, 'address': '荃灣', 'managerName': '李先生'},
        ],
      };
    }
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/home'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return data;
  }

  /// 工人資料
  Future<Map<String, dynamic>> getWorkerProfile() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/profile'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return data;
  }

  /// 更新工人個人資料（直接保存，無需審核）
  Future<Map<String, dynamic>> updateWorkerProfile(Map<String, dynamic> body) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/worker/profile'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(body),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return data;
  }

  // ===== Face Registration =====

  /// 人臉登記（Base64）
  Future<void> registerFaceBase64(String base64Image) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/worker/face-register-base64'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'image': base64Image}),
    );
    _handleError(resp);
  }

  /// 人臉驗證（打卡時比對）
  Future<Map<String, dynamic>> verifyFace(String base64Image) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/worker/verify-face'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'image': base64Image}),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('驗證傳回數據為空');
    return data as Map<String, dynamic>;
  }

  // ===== Site Application =====

  /// 申請加入地盤（含所屬公司、每日薪酬、合約附件）
  Future<Map<String, dynamic>> applySite({
    required int siteId,
    required int companyId,
    required String dailyWage,
    required String contractAttachment,
    String remark = '',
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/worker/apply-site'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({
        'siteId': siteId,
        'companyId': companyId,
        'dailyWage': dailyWage,
        'contractAttachment': contractAttachment,
        'remark': remark,
      }),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return data;
  }

  /// 獲取判頭公司列表（申請地盤時選擇所屬公司用）
  Future<List<dynamic>> getContractorCompanies() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/company/contractor-list'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 判頭：獲取待審核申請列表
  Future<List<dynamic>> getContractorApplications() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/contractor/applications'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 判頭：獲取待審核申請數量
  Future<int> getPendingApplicationCount() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/contractor/applications/pending-count'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    return (data['count'] as num).toInt();
  }

  /// 判頭：審核申請（批准/拒絕）
  Future<Map<String, dynamic>> reviewContractorApplication({
    required int applicationId,
    required bool approved,
    String reviewRemark = '',
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/contractor/review-application'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({
        'applicationId': applicationId,
        'approved': approved,
        'reviewRemark': reviewRemark,
      }),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('返回數據為空');
    return data;
  }

  /// 判頭：獲取更換地盤待審核申請列表
  Future<List<dynamic>> getChangeRequests() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/contractor/change-requests'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 判頭：審核更換地盤申請（批准/拒絕）
  Future<void> reviewChangeRequest({
    required int requestId,
    required bool approved,
    String reviewRemark = '',
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/contractor/review-change'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({
        'requestId': requestId,
        'approved': approved,
        'reviewRemark': reviewRemark,
      }),
    );
    _handleError(resp);
  }

  /// 判頭：獲取自己公司下的地盤列表
  Future<List<dynamic>> getContractorSites() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/contractor/sites'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 判頭：獲取指定地盤下的工人列表（含今日考勤狀態）
  /// siteId 為 null 時返回公司下所有工人
  Future<Map<String, dynamic>> getSiteWorkers({int? siteId}) async {
    final uri = Uri.parse('$baseUrl/contractor/site-workers').replace(
      queryParameters: siteId != null ? {'siteId': siteId.toString()} : null,
    );
    final resp = await _client.get(uri, headers: ApiConfig.headers(token: token));
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  /// 獲取通知列表
  Future<List<dynamic>> getNotifications({bool unreadOnly = false}) async {
    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: unreadOnly ? {'unreadOnly': 'true'} : null,
    );
    final resp = await _client.get(uri, headers: ApiConfig.headers(token: token));
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 獲取未讀通知數量
  Future<int> getUnreadNotificationCount() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final count = jsonDecode(resp.body)['data'];
    return count is int ? count : int.tryParse(count.toString()) ?? 0;
  }

  /// 標記通知為已讀
  Future<void> markNotificationRead(int notificationId) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  /// 標記所有通知為已讀
  Future<void> markAllNotificationsRead() async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  /// 我的申請列表
  Future<List<dynamic>> getMyApplications() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/my-applications'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 我的更換地盤申請列表
  Future<List<dynamic>> getMyChangeRequests() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/my-change-requests'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List;
  }

  /// 獲取當前地盤的安全分（按地盤維度，總分15分）
  Future<Map<String, dynamic>> getSiteSafetyScore() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/site-safety-score'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  // ===== Site APIs =====

  /// 獲取地盤列表（供申請時選擇）
  Future<List<dynamic>> getSites() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/site/list'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) return [];
    return data as List<dynamic>;
  }

  /// 獲取當前地盤
  Future<Map<String, dynamic>?> getCurrentSite() async {
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/site/current'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      return jsonDecode(resp.body)['data'];
    } catch (e) {
      return null; // No site assigned
    }
  }

  /// 申請更換地盤（工人發起）
  Future<void> changeSite({
    required int targetSiteId,
    required String reason,
    String? dailyWage,
    String? contractAttachment,
  }) async {
    if (ApiConfig.mockMode) return;
    final body = <String, dynamic>{
      'targetSiteId': targetSiteId,
      'reason': reason,
    };
    if (dailyWage != null) body['dailyWage'] = dailyWage;
    if (contractAttachment != null) body['contractAttachment'] = contractAttachment;
    final resp = await _client.post(
      Uri.parse('$baseUrl/site/change'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(body),
    );
    _handleError(resp);
  }

  /// 取消更換地盤申請
  Future<void> cancelChangeSite() async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/site/cancel-change'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  /// 獲取更換地盤歷史記錄
  Future<Map<String, dynamic>> getChangeHistory({int page = 0, int size = 10}) async {
    if (ApiConfig.mockMode) return {'content': [], 'totalElements': 0, 'totalPages': 0};
    final resp = await _client.get(
      Uri.parse('$baseUrl/site/history?page=$page&size=$size'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  // ===== Safety Video APIs =====

  /// 獲取所有安全影片列表
  Future<List<dynamic>> getSafetyVideos() async {
    if (ApiConfig.mockMode) {
      return [
        {'id': 1, 'title': '工地安全守則入門', 'description': '介紹基本工地安全規範', 'videoUrl': '', 'duration': 30, 'mandatory': true},
        {'id': 2, 'title': '高空作業安全須知', 'description': '高空工作安全要點', 'videoUrl': '', 'duration': 25, 'mandatory': true},
      ];
    }
    final resp = await _client.get(
      Uri.parse('$baseUrl/safety/videos'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) return [];
    return data as List<dynamic>;
  }

  /// 記錄影片觀看進度
  Future<void> markVideoWatched(int videoId, int watchedDuration) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/safety/video-watched'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({
        'videoId': videoId,
        'watchedDuration': watchedDuration,
      }),
    );
    _handleError(resp);
  }

  /// 檢查必修安全影片是否全部完成，是否可以打卡
  Future<bool> isSafetyCheckInAllowed() async {
    if (ApiConfig.mockMode) return true;
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/safety/completion-status'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      final data = jsonDecode(resp.body)['data'];
      return data['checkInAllowed'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 获取天气警告（台风/暴雨/酷热/工作暑热）
  Future<Map<String, dynamic>> getWeatherWarnings() async {
    if (ApiConfig.mockMode) return {'warnsum': '{}', 'hsww': '{}'};
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/worker/weather-warnings'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      final data = jsonDecode(resp.body)['data'];
      if (data == null) return {'warnsum': '{}', 'hsww': '{}'};
      return data as Map<String, dynamic>;
    } catch (_) {
      return {'warnsum': '{}', 'hsww': '{}'};
    }
  }

  /// 获取天气警告（内部人员专用）
  Future<Map<String, dynamic>> getInternalWeatherWarnings() async {
    if (ApiConfig.mockMode) return {'warnsum': '{}', 'hsww': '{}'};
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/internal/weather-warnings'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      final data = jsonDecode(resp.body)['data'];
      if (data == null) return {'warnsum': '{}', 'hsww': '{}'};
      return data as Map<String, dynamic>;
    } catch (_) {
      return {'warnsum': '{}', 'hsww': '{}'};
    }
  }

  // ===== Attendance APIs =====

  /// 入場/離場打卡
  /// 返回打卡記錄 (Map)，包含 checkInTime, checkOutTime, siteName 等
  Future<Map<String, dynamic>> checkIn({
    double? latitude,
    double? longitude,
    required String checkInType,
    required int siteId,
    String? bluetoothBeaconId,
    List<Map<String, dynamic>>? nearbyBeacons,
    String? photo,
  }) async {
    if (ApiConfig.mockMode) return {};
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'checkInType': checkInType,
      'siteId': siteId,
    };
    if (bluetoothBeaconId != null && bluetoothBeaconId.isNotEmpty) {
      body['bluetoothBeaconId'] = bluetoothBeaconId;
    }
    if (nearbyBeacons != null && nearbyBeacons.isNotEmpty) {
      body['nearbyBeacons'] = nearbyBeacons;
    }
    if (photo != null && photo.isNotEmpty) {
      body['photo'] = photo;
    }
    final resp = await _client.post(
      Uri.parse('$baseUrl/attendance/check-in'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(body),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('打卡傳回資料為空');
    return data as Map<String, dynamic>;
  }

  /// 查詢指定日期的考勤記錄
  /// 返回 Map (包含 checkInTime, checkOutTime, siteName)，無記錄則抛異常
  Future<Map<String, dynamic>> getDailyAttendance(String date) async {
    if (ApiConfig.mockMode) return {};
    final resp = await _client.get(
      Uri.parse('$baseUrl/attendance/daily?date=$date'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('NO_RECORD');
    return data as Map<String, dynamic>;
  }

  /// 查詢指定月份有打卡記錄的日期（返回日期數字列表，如 [1, 3, 5]）
  Future<List<dynamic>> getMonthlyAttendance(int year, int month) async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/attendance/monthly?year=$year&month=$month'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) return [];
    return data as List<dynamic>;
  }

  // ===== File Upload =====

  /// 上傳文件（支持 Web，使用 bytes）
  /// 返回服務器上的文件 URL
  Future<String> uploadFile({
    required Uint8List bytes,
    required String filename,
    String folder = 'uploads',
  }) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['folder'] = folder;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('上傳返回數據為空');
    return data['url'] ?? data.toString();
  }

  // ===== Company Change APIs (更換公司) =====

  /// 工人：提交更換公司申請
  Future<void> requestCompanyChange({
    required int toCompanyId,
    String reason = '',
    double? dailySalary,
    Uint8List? contractFileBytes,
    String? contractFileName,
  }) async {
    if (ApiConfig.mockMode) return;

    final uri = Uri.parse('$baseUrl/worker/request-company-change');
    final currentToken = token;
    if (currentToken == null) throw Exception('用戶未登錄，請重新登錄');

    // 如果有文件，需要用 MultipartRequest（但手動設置 header 避免 charset）
    if (contractFileBytes != null && contractFileName != null) {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $currentToken';
      request.headers['Accept'] = 'application/json';
      // 關鍵：不設置 Content-Type，讓 http 包自動生成（不帶 charset）
      request.fields['toCompanyId'] = toCompanyId.toString();
      request.fields['reason'] = reason;
      if (dailySalary != null) request.fields['dailySalary'] = dailySalary.toString();
      request.files.add(http.MultipartFile.fromBytes('contractAttachment', contractFileBytes, filename: contractFileName));

      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);
      _handleError(resp);
    } else {
      // 無文件時，使用 JSON（避免 multipart 的 charset 問題）
      final resp = await _client.post(
        uri,
        headers: ApiConfig.headers(token: currentToken),
        body: jsonEncode({
          'toCompanyId': toCompanyId,
          'reason': reason,
          if (dailySalary != null) 'dailySalary': dailySalary,
        }),
      );
      _handleError(resp);
    }
  }

  /// 工人：獲取我的更換公司申請列表
  Future<List<dynamic>> getMyCompanyChangeRequests() async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/worker/my-company-change-requests'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List<dynamic>;
  }

  /// 工人：取消更換公司申請
  Future<void> cancelCompanyChange() async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.delete(
      Uri.parse('$baseUrl/worker/cancel-company-change'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  /// 判頭：獲取待審核的更換公司申請列表
  Future<List<dynamic>> getContractorCompanyChangeRequests() async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/contractor/company-change-requests'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as List<dynamic>;
  }

  /// 判頭：審核更換公司申請（批准/拒絕）
  Future<void> reviewCompanyChange({
    required int requestId,
    required bool approved,
    String reviewRemark = '',
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/contractor/review-company-change'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({
        'requestId': requestId,
        'approved': approved,
        'reviewRemark': reviewRemark,
      }),
    );
    _handleError(resp);
  }

  // ===== Helper =====

  void _handleError(http.Response resp) {
    // 檢查 HTTP 狀態碼
    if (resp.statusCode >= 400) {
      try {
        final body = jsonDecode(resp.body);
        throw Exception(body['message'] ?? body['msg'] ?? '請求失敗');
      } catch (e) {
        // jsonDecode 失败（如非 JSON）→ 用 HTTP 状态码兜底；已抛出的业务异常 → 继续传播
        if (e is FormatException) {
          throw Exception('請求失敗 (${resp.statusCode})');
        } else {
          rethrow;
        }
      }
    }
    // 後端異常處理器可能返回 HTTP 200 但 body 中 code >= 400
    try {
      final body = jsonDecode(resp.body);
      final code = body['code'];
      if (code != null && code is int && code >= 400) {
        throw Exception(body['message'] ?? body['msg'] ?? '請求失敗 (code: $code)');
      }
    } catch (e) {
      // jsonDecode 失败（如非 JSON 响应）→ 静默；主动抛出的异常 → 继续传播
      if (e is FormatException) {
        // 非 JSON 响应，忽略
      } else {
        rethrow;
      }
    }
  }

  void dispose() {
    _client.close();
  }

  // ===== Internal Staff APIs =====

  /// 獲取地盤總覽（各地盤工人統計）
  Future<List<Map<String, dynamic>>> getInternalSites() async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/sites'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return (jsonDecode(resp.body)['data'] as List).cast<Map<String, dynamic>>();
  }

  /// 獲取所有公司（供搜索下拉用）
  Future<List<Map<String, dynamic>>> getInternalCompanies() async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/companies'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return (jsonDecode(resp.body)['data'] as List).cast<Map<String, dynamic>>();
  }

  /// 搜索工人
  Future<List<Map<String, dynamic>>> searchInternalWorkers({
    String? name,
    int? companyId,
  }) async {
    if (ApiConfig.mockMode) return [];
    final params = <String, String>{};
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (companyId != null) params['companyId'] = companyId.toString();
    final uri = Uri.parse('$baseUrl/internal/workers/search').replace(queryParameters: params.isEmpty ? null : params);
    final resp = await _client.get(uri, headers: ApiConfig.headers(token: token));
    _handleError(resp);
    return (jsonDecode(resp.body)['data'] as List).cast<Map<String, dynamic>>();
  }

  /// 按工人編號查詢工人資訊
  Future<Map<String, dynamic>> getWorkerByNumber(String workerNumber) async {
    if (ApiConfig.mockMode) return {};
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/workers/by-number/$workerNumber'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    final data = jsonDecode(resp.body)['data'];
    if (data == null) throw Exception('未找到該工人');
    return data as Map<String, dynamic>;
  }

  /// 獲取被鎖卡工人列表
  Future<List<Map<String, dynamic>>> getLockedWorkers() async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/workers/locked'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return (jsonDecode(resp.body)['data'] as List).cast<Map<String, dynamic>>();
  }

  /// 扣分
  Future<Map<String, dynamic>> deductWorkerScore(int workerId, int points, String reason) async {
    if (ApiConfig.mockMode) return {};
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/workers/$workerId/deduct'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'points': points, 'reason': reason}),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  /// 鎖卡/解鎖
  Future<void> toggleWorkerLock(int workerId, bool lock) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/workers/$workerId/toggle-lock'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'lock': lock}),
    );
    _handleError(resp);
  }

  /// 添加黑名單
  Future<void> addBlacklist(int workerId, String reason) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/admin/blacklist/add'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'workerId': workerId, 'reason': reason}),
    );
    _handleError(resp);
  }

  // ===== Internal Staff Home APIs =====

  /// 內部人員首頁數據
  Future<Map<String, dynamic>> getInternalHome() async {
    if (ApiConfig.mockMode) {
      return {
        'user': {'name': '測試管理員', 'phone': '10000000001', 'role': 'SITE_MANAGER'},
        'currentSite': null,
        'hasSite': false,
        'hasPendingApplication': false,
        'pendingApplication': null,
        'mySites': [],
        'availableSites': [],
        'todayAttendance': null,
      };
    }
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/home'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  /// 內部人員申請加入地盤
  Future<Map<String, dynamic>> applyInternalSite(int siteId) async {
    if (ApiConfig.mockMode) return {'autoApproved': true};
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/apply-site'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode({'siteId': siteId}),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  /// 撤銷內部人員地盤申請
  Future<void> cancelInternalSiteApplication() async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/cancel-site-application'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  /// 獲取已加入的地盤列表
  Future<List<Map<String, dynamic>>> getMySites() async {
    if (ApiConfig.mockMode) return [];
    final resp = await _client.get(
      Uri.parse('$baseUrl/internal/my-sites'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
    return (jsonDecode(resp.body)['data'] as List).cast<Map<String, dynamic>>();
  }

  /// 切換當前地盤
  Future<void> switchSite(int siteId) async {
    if (ApiConfig.mockMode) return;
    final resp = await _client.put(
      Uri.parse('$baseUrl/internal/switch-site/$siteId'),
      headers: ApiConfig.headers(token: token),
    );
    _handleError(resp);
  }

  // ===== Internal Staff Attendance APIs =====

  /// 内部人员打卡
  Future<Map<String, dynamic>> internalCheckIn({int? siteId, String checkInType = 'MANUAL'}) async {
    if (ApiConfig.mockMode) return {};
    final body = <String, dynamic>{'checkInType': checkInType};
    if (siteId != null) body['siteId'] = siteId;
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/check-in'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(body),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }

  /// 内部人员获取今日考勤
  Future<Map<String, dynamic>?> internalGetDailyAttendance(String date) async {
    if (ApiConfig.mockMode) return null;
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/internal/attendance/daily?date=$date'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      final data = jsonDecode(resp.body)['data'];
      if (data == null || data is! Map) return null;
      return data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 内部人员获取月度考勤
  Future<List<int>> internalGetMonthlyAttendance(int year, int month) async {
    if (ApiConfig.mockMode) return [];
    try {
      final resp = await _client.get(
        Uri.parse('$baseUrl/internal/attendance/monthly?year=$year&month=$month'),
        headers: ApiConfig.headers(token: token),
      );
      _handleError(resp);
      final data = jsonDecode(resp.body)['data'];
      if (data == null || data is! List) return [];
      return (data).cast<int>();
    } catch (_) {
      return [];
    }
  }

  /// 按手机号加入黑名单 + 更新平安卡信息
  Future<Map<String, dynamic>> blacklistByPhone({
    required String phone,
    required String reason,
    String? safetyCardNumber,
    String? safetyCardAttachment,
  }) async {
    if (ApiConfig.mockMode) return {};
    final body = <String, dynamic>{
      'phone': phone,
      'reason': reason,
    };
    if (safetyCardNumber != null && safetyCardNumber.isNotEmpty) {
      body['safetyCardNumber'] = safetyCardNumber;
    }
    if (safetyCardAttachment != null && safetyCardAttachment.isNotEmpty) {
      body['safetyCardAttachment'] = safetyCardAttachment;
    }
    final resp = await _client.post(
      Uri.parse('$baseUrl/internal/workers/blacklist-by-phone'),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(body),
    );
    _handleError(resp);
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>;
  }
}
