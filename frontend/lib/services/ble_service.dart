import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';

/// 单个 Beacon 信息
class BeaconInfo {
  final String uuid;
  final int rssi;
  final double estimatedDistanceMeters;

  BeaconInfo({
    required this.uuid,
    required this.rssi,
    required this.estimatedDistanceMeters,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'rssi': rssi,
    'distance': estimatedDistanceMeters,
  };
}

/// BLE 扫描结果
class BeaconScanResult {
  /// 匹配到的 Beacon UUID（未匹配则为 null）
  final String? matchedUuid;

  /// 扫描期间发现的所有 Beacon（去重，保留最新 RSSI）
  final List<BeaconInfo> allBeacons;

  BeaconScanResult({this.matchedUuid, required this.allBeacons});
}

/// BLE 蓝牙信标扫描服务
/// 用于扫描附近的 iBeacon 设备，提取 ProximityUUID 并与地盘配置的信标列表进行匹配
class BleService {
  static final BleService _instance = BleService._();
  factory BleService() => _instance;
  BleService._();

  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  /// 是否正在扫描
  bool get isScanning => _isScanning;

  /// 扫描附近的 iBeacon 设备，匹配地盘配置的信标 UUID 列表
  ///
  /// [expectedBeaconIds] 地盘配置的信标 UUID 列表（逗号分隔），如 "uuid1,uuid2"
  /// [timeout] 扫描超时时间，默认 10 秒
  ///
  /// 返回扫描结果，包含匹配的 UUID 及所有检测到的 Beacon 信息
  Future<BeaconScanResult> scanForBeacon(String expectedBeaconIds, {Duration timeout = const Duration(seconds: 10)}) async {
    // 1. 检查蓝牙状态
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('[BleService] 蓝牙未开启: $adapterState');
      throw BleException('藍牙未開啟，請先開啟藍牙');
    }

    // 2. 解析期望的信标 UUID 列表（逗号分割，trim，转小写）
    final expectedUuids = expectedBeaconIds
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (expectedUuids.isEmpty) {
      debugPrint('[BleService] 无期望的信标 UUID');
      return BeaconScanResult(matchedUuid: null, allBeacons: []);
    }

    debugPrint('[BleService] 开始扫描，期望信标: $expectedUuids');

    // 3. 累积所有检测到的 Beacon（UUID → 最新 BeaconInfo）
    final Map<String, BeaconInfo> allDetected = {};

    // 4. 开始扫描
    final completer = Completer<String?>(); // matched UUID
    Timer? timer;

    try {
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        _scanSubscription?.cancel();
      }

      _isScanning = true;

      // 监听扫描结果
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final parsed = _parseIBeacon(result);
          if (parsed == null) continue;

          final uuid = parsed['uuid'] as String;
          final rssi = result.rssi;
          final txPower = parsed['txPower'] as int;
          final distance = _estimateDistance(rssi, txPower);

          // 更新该 UUID 的最新 RSSI（取信号最强的一次）
          final existing = allDetected[uuid.toLowerCase()];
          if (existing == null || rssi > existing.rssi) {
            allDetected[uuid.toLowerCase()] = BeaconInfo(
              uuid: uuid,
              rssi: rssi,
              estimatedDistanceMeters: distance,
            );
          }

          debugPrint('[BleService] 发现 iBeacon: UUID=$uuid, RSSI=$rssi, 估算距离=${distance.toStringAsFixed(1)}m');

          // 匹配检查
          if (!completer.isCompleted && expectedUuids.contains(uuid.toLowerCase())) {
            debugPrint('[BleService] 信标匹配成功: $uuid (RSSI=$rssi, ${distance.toStringAsFixed(1)}m)');
            completer.complete(uuid);
          }
        }
      });

      // 启动扫描
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // 设置超时
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          debugPrint('[BleService] 扫描超时 (${timeout.inSeconds}s)');
          completer.complete(null);
        }
      });

      final matchedUuid = await completer.future;

      // 记录扫描汇总
      debugPrint('[BleService] 扫描结束: 共检测到 ${allDetected.length} 个 Beacon, 匹配=${matchedUuid ?? "无"}');

      return BeaconScanResult(
        matchedUuid: matchedUuid,
        allBeacons: allDetected.values.toList(),
      );
    } catch (e) {
      debugPrint('[BleService] 扫描出错: $e');
      if (e is BleException) rethrow;
      throw BleException('藍牙掃描失敗: $e');
    } finally {
      timer?.cancel();
      _scanSubscription?.cancel();
      _isScanning = false;
    }
  }

  /// 解析 iBeacon 广播数据，返回 {uuid, txPower} 或 null
  ///
  /// flutter_blue_plus 的 manufacturerData:
  ///   key = 厂商 ID, value = 厂商 ID 之后的数据
  /// iBeacon 数据部分 (value, 共 23 字节):
  ///   Byte 0:    iBeacon Type (0x02)
  ///   Byte 1:    Data Length (0x15 = 21)
  ///   Byte 2-17: ProximityUUID (16 bytes)
  ///   Byte 18-19: Major (2 bytes)
  ///   Byte 20-21: Minor (2 bytes)
  ///   Byte 22:   TX Power (1 byte, signed)
  Map<String, Object>? _parseIBeacon(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    if (manufacturerData.isEmpty) return null;

    for (final entry in manufacturerData.entries) {
      final manufacturerId = entry.key;
      final data = entry.value;

      // Apple Company ID = 0x004C = 76
      if (manufacturerId != 0x004C) continue;
      if (data.length < 23) continue;  // iBeacon 数据 23 字节（不含 Company ID）
      if (data[0] != 0x02) continue;  // iBeacon type
      if (data[1] != 0x15) continue;  // iBeacon data length

      // 提取 ProximityUUID (bytes 2-17)
      final uuidBytes = data.sublist(2, 18);
      final uuid = _formatUuid(uuidBytes);
      if (uuid == null) continue;

      // 提取 TX Power (byte 22, signed)
      int txPower = data[22];
      if (txPower > 127) txPower -= 256; // 转换有符号

      return {'uuid': uuid, 'txPower': txPower};
    }

    return null;
  }

  /// 将 16 字节的 UUID 数据格式化为标准 UUID 字符串
  String? _formatUuid(List<int> bytes) {
    if (bytes.length != 16) return null;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// 根据 RSSI 和 TX Power 估算距离（米）
  ///
  /// 公式: distance = 10 ^ ((txPower - rssi) / (10 * n))
  ///   n = 环境衰减因子 (2 = 自由空间, 2.5~3 = 室内)
  double _estimateDistance(int rssi, int txPower) {
    const double n = 2.5; // 建筑工地室内环境
    if (rssi == 0) return -1.0;
    final ratio = (txPower - rssi) / (10.0 * n);
    return pow(10, ratio).toDouble();
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
    }
  }

  /// 释放资源
  void dispose() {
    stopScan();
  }
}

/// 蓝牙异常
class BleException implements Exception {
  final String message;
  BleException(this.message);

  @override
  String toString() => 'BleException: $message';
}
