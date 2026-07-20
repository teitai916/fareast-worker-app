import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 生物识别服务：指纹/面容登录
/// 凭证存储在系统级安全存储（iOS Keychain / Android EncryptedSharedPreferences），
/// 仅通过生物识别验证后才可读取，用于在 token 失效/被登出后快速重新登录。
class BiometricService {
  static final _auth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage();
  static const _keyPassword = 'biometric_password';
  static const _keyPhone = 'biometric_phone';
  static const _keyEnabled = 'biometric_enabled';

  /// 检查设备是否支持生物识别（指纹/面容）
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      debugPrint('[Biometric] canCheckBiometrics=$canCheck');
      final isDeviceSupported = await _auth.isDeviceSupported();
      debugPrint('[Biometric] isDeviceSupported=$isDeviceSupported');
      final available = canCheck && isDeviceSupported;
      debugPrint('[Biometric] isAvailable=$available');
      if (available) {
        final types = await getAvailableBiometrics();
        debugPrint('[Biometric] availableTypes=$types');
      }
      return available;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('[Biometric] isAvailable error: $e');
      return false;
    }
  }

  /// 获取可用的生物识别类型列表
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 触发生物识别验证
  /// [reason] 为系统弹窗中显示的说明文字
  /// 返回 true 表示验证通过
  static Future<bool> authenticate({
    String reason = '請使用指紋/面容驗證身份',
  }) async {
    try {
      debugPrint('[Biometric] authenticate 开始, reason=$reason');
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      debugPrint('[Biometric] authenticate 结果=$didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] authenticate PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('[Biometric] authenticate error: $e');
      return false;
    }
  }

  /// 是否已启用生物识别登录
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 设置生物识别登录开关
  /// 关闭时会同时清除存储的凭证
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    if (!enabled) {
      await _secureStorage.delete(key: _keyPassword);
      await _secureStorage.delete(key: _keyPhone);
    }
  }

  /// 保存登录凭证（首次密码登录成功后，用户同意启用时调用）
  static Future<void> saveCredentials(String phone, String password) async {
    await _secureStorage.write(key: _keyPhone, value: phone);
    await _secureStorage.write(key: _keyPassword, value: password);
    await setBiometricEnabled(true);
  }

  /// 读取保存的登录凭证
  static Future<({String phone, String password})?> getCredentials() async {
    try {
      final phone = await _secureStorage.read(key: _keyPhone);
      final password = await _secureStorage.read(key: _keyPassword);
      if (phone != null && phone.isNotEmpty &&
          password != null && password.isNotEmpty) {
        return (phone: phone, password: password);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 清除凭证（用户主动关闭或登录失败时调用）
  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyPhone);
    await _secureStorage.delete(key: _keyPassword);
    await setBiometricEnabled(false);
  }

  /// 生物识别自动登录
  /// 流程：检查启用 → 读凭证 → 指纹/面容验证 → POST /auth/login
  /// 返回 true 表示登录成功（token 已写入 TokenManager）
  static Future<bool> biometricLogin() async {
    debugPrint('[Biometric] biometricLogin 開始');
    // 1. 检查是否启用
    final enabled = await isBiometricEnabled();
    debugPrint('[Biometric] isBiometricEnabled=$enabled');
    if (!enabled) return false;

    // 2. 检查是否有凭证
    final credentials = await getCredentials();
    debugPrint('[Biometric] credentials=${credentials != null ? "有" : "无"}');
    if (credentials == null) return false;

    // 3. 生物识别验证
    final authenticated = await authenticate();
    if (!authenticated) return false;

    // 4. 调 login API（内部自动 setToken + setUser）
    try {
      debugPrint('[Biometric] 调用 login API...');
      await ApiService().login(credentials.phone, credentials.password);
      debugPrint('[Biometric] login 成功');
      return true;
    } catch (e) {
      debugPrint('[Biometric] login 失败: $e');
      await clearCredentials();
      return false;
    }
  }
}
