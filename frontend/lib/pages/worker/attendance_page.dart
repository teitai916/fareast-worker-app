import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  // 定位失败连续次数（超过 3 次提示检查环境）
  int _locationFailCount = 0;
  // 當前時間
  String _currentTime = '';
  Timer? _timer;

  // 選中的日期（每日考勤記錄欄顯示此日期的記錄）
  late DateTime _selectedDate;

  // 日曆顯示的月份
  late DateTime _calendarMonth;

  // 今日考勤記錄
  Map<String, dynamic>? _todayRecord;
  bool _loadingRecord = false;

  // 本月有打卡的日期列表（日數 1-31）
  List<int> _monthlyDays = [];

  // 工人所屬地盤 ID（從工人資料獲取，打卡時使用）
  int? _currentSiteId;
  String? _currentSiteName;

  // 打卡狀態
  bool get _checkedIn {
    if (_todayRecord == null) return false;
    final checkIn = _todayRecord!['checkInTime'];
    final checkOut = _todayRecord!['checkOutTime'];
    return checkIn != null && checkOut == null;
  }

  // 今日是否已全部完成（入場+離場均已打卡）
  bool get _allDone {
    if (_todayRecord == null) return false;
    final checkIn = _todayRecord!['checkInTime'];
    final checkOut = _todayRecord!['checkOutTime'];
    return checkIn != null && checkOut != null;
  }

  String? get _checkInTimeStr => _formatTime(_todayRecord?['checkInTime']);
  String? get _checkOutTimeStr => _formatTime(_todayRecord?['checkOutTime']);
  String? get _siteName => _todayRecord?['siteName'] as String?;

  String? _formatTime(dynamic t) {
    if (t == null) return null;
    if (t is String) {
      // "2026-06-06T08:30:00" → "08:30:00"
      final parts = t.split('T');
      if (parts.length == 2) {
        return parts[1].substring(0, 8); // HH:mm:ss
      }
    }
    return null;
  }

  String get _selectedDateStr =>
      '${_selectedDate.year}-${_pad(_selectedDate.month)}-${_pad(_selectedDate.day)}';

  String get _calendarMonthStr =>
      '${_calendarMonth.year}年${_calendarMonth.month}月';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _loadWorkerProfile();
    _loadTodayRecord();
    _loadMonthlyDays();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
    });
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 載入指定日期的考勤記錄
  Future<void> _loadDailyRecord(DateTime date) async {
    setState(() => _loadingRecord = true);
    final dateStr =
        '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
    try {
      final record = await ApiService().getDailyAttendance(dateStr);
      setState(() {
        _todayRecord = record;
        _loadingRecord = false;
      });
    } catch (e) {
      if (e.toString().contains('NO_RECORD')) {
        setState(() {
          _todayRecord = null;
          _loadingRecord = false;
        });
      } else {
        setState(() => _loadingRecord = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入記錄失敗: $e')),
          );
        }
      }
    }
  }

  /// 載入今日考勤記錄
  Future<void> _loadTodayRecord() => _loadDailyRecord(DateTime.now());

  /// 載入本月有打卡的日期
  Future<void> _loadMonthlyDays() async {
    try {
      final days = await ApiService().getMonthlyAttendance(
        _calendarMonth.year,
        _calendarMonth.month,
      );
      setState(() {
        _monthlyDays = days.cast<int>();
      });
    } catch (e) {
      // 忽略錯誤，日曆不顯示高亮
    }
  }

  /// 載入工人資料，獲取所屬地盤 ID 和名稱
  /// 使用 getWorkerHome() 中的 currentSite，因為它包含 id 和 name
  Future<void> _loadWorkerProfile() async {
    try {
      final homeData = await ApiService().getWorkerHome();
      final currentSite = homeData['currentSite'] as Map<String, dynamic>?;
      setState(() {
        _currentSiteId = currentSite?['id'] as int?;
        _currentSiteName = currentSite?['name'] as String?;
      });
    } catch (e) {
      // 載入失敗不阻斷打卡功能，_onCheckIn 會處理
    }
  }

  /// 切換到上個月
  void _prevMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
    });
    _loadMonthlyDays();
  }

  /// 切換到下個月
  void _nextMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
    });
    _loadMonthlyDays();
  }

  /// 選中某一天
  void _onDaySelected(int day) {
    setState(() {
      _selectedDate = DateTime(_calendarMonth.year, _calendarMonth.month, day);
    });
    _loadDailyRecord(_selectedDate);
  }

  /// 打卡（入場/離場）
  Future<void> _onCheckIn() async {
    // 離場打卡前彈出確認框
    if (_checkedIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('確認離場打卡'),
          content: const Text('確認要進行離場打卡嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
              child: const Text('確認離場'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // 獲取地盤 ID
    final siteId = _currentSiteId ??
        (_todayRecord != null ? _todayRecord!['siteId'] as int? : null);
    if (siteId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無法獲取地盤資訊，請稍後再試'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // 獲取 GPS 定位
    final position = await _getPosition();
    if (position == null) return; // 定位失败已在 _getPosition 中处理
    _locationFailCount = 0;

    // 人臉驗證
    final facePassed = await _showFaceVerification();
    if (!facePassed) return;

    try {
      final result = await ApiService().checkIn(
        latitude: position.latitude,
        longitude: position.longitude,
        checkInType: 'BLUETOOTH',
        siteId: siteId,
      );
      await _loadTodayRecord();
      await _loadMonthlyDays();
      if (!mounted) return;
      final isCheckOut = result['checkOutTime'] != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckOut ? '離場打卡成功！' : '入場打卡成功！'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打卡失敗：$errorMsg'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// 獲取 GPS 定位，處理各種異常情況
  Future<Position?> _getPosition() async {
    // 1. 檢查 GPS 是否開啟
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationFailCount++;
      if (!mounted) return null;
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('GPS 未開啟'),
          content: const Text('打卡需要使用您的位置資訊以確認您在地盤範圍內。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消打卡'),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.pop(ctx, false);
              },
              child: const Text('前往設定開啟'),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        // 等待用户返回后重试
        await Future.delayed(const Duration(seconds: 1));
        return _getPosition(); // 递归重试
      }
      return null;
    }

    // 2. 檢查定位權限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需允許定位權限才能打卡'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _locationFailCount++;
      if (!mounted) return null;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('定位權限已關閉'),
          content: const Text('打卡需要使用您的位置資訊，請前往系統設定開啟定位權限。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消打卡'),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.pop(ctx);
              },
              child: const Text('前往設定開啟'),
            ),
          ],
        ),
      );
      return null;
    }

    // 3. 獲取當前位置（超時 10 秒）
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 4. 精度警告（精度 > 50m 時提示，不阻斷流程）
      if (position.accuracy != null && position.accuracy! > 50) {
        if (!mounted) return position; // 仍返回位置，不阻斷
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('定位訊號較弱，請移至空曠處'),
            backgroundColor: AppTheme.warningColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return position;
    } on TimeoutException {
      _locationFailCount++;
      if (!mounted) return null;

      if (_locationFailCount >= 3) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('定位超時'),
            content: const Text('多次獲取位置失敗，請確保您在室外空曠環境，GPS 訊號良好。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
        _locationFailCount = 0;
        return null;
      }

      // 未達 3 次，彈窗重試
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('定位超時'),
          content: const Text('獲取位置資訊超時，請確保已開啟 GPS 並在室外環境。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消打卡'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('重試'),
            ),
          ],
        ),
      );
      if (retry == true) return _getPosition(); // 递归重试
      return null;
    } catch (e) {
      _locationFailCount++;
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('定位失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return null;
    }
  }

  /// 人臉驗證：打開相機拍照 → 發送到後端比對 → 返回是否通過
  Future<bool> _showFaceVerification() async {
    final picker = ImagePicker();

    // 彈出驗證提示
    if (!mounted) return false;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('人臉驗證'),
        content: const Text('打卡前需要進行人臉驗證，請準備拍照。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消打卡'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('開始拍照'),
          ),
        ],
      ),
    );
    if (shouldProceed != true) return false;

    // 拍照
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) return false;

    // 轉 base64
    final bytes = await pickedFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 顯示驗證中
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在驗證人臉...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final result = await ApiService().verifyFace(base64Image);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final matched = result['matched'] == true;
      final score = result['score'] ?? 0;

      if (matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('人臉驗證通過（匹配度：$score/100）'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        return true;
      } else {
        // 未通過，提供重試選項
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('人臉驗證失敗'),
            content: Text('匹配度 $score/100，未達到 60 分的標準。\n請確保光線充足、臉部正對鏡頭。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消打卡'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('重試'),
              ),
            ],
          ),
        );
        if (retry == true) return _showFaceVerification(); // 递归重试
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('人臉驗證失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_todayRecord != null &&
            _checkInTimeStr != null &&
            _checkOutTimeStr != null)
        ? _calcHours(_todayRecord!['checkInTime'], _todayRecord!['checkOutTime'])
        : '--';

    return Scaffold(
      appBar: AppBar(title: const Text('考勤打卡')),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // 左右滑動切換月份
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) {
              _prevMonth();
            } else {
              _nextMonth();
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 當前時間顯示
              _buildTimeCard(),
              const SizedBox(height: 24),

              // 打卡按鈕
              _buildCheckInButton(),
              const SizedBox(height: 8),
              Text(
                _allDone
                    ? '今日打卡已完成，明天再來吧！'
                    : _checkedIn
                        ? '點擊按鈕進行離場打卡'
                        : '點擊按鈕進行入場打卡（需開啟藍牙/定位）',
                style: TextStyle(
                  color: _allDone ? AppTheme.successColor : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // 每日考勤記錄
              _buildDailyRecordCard(hours),
              const SizedBox(height: 16),

              // 本月考勤日曆
              _buildMonthlyCalendar(),
            ],
          ),
        ),
      ),
    );
  }

  /// 當前時間卡片
  Widget _buildTimeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('當前時間', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _currentTime,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  /// 打卡按鈕（圓形）
  Widget _buildCheckInButton() {
    final allDone = _allDone;
    final checkedIn = _checkedIn;

    return Opacity(
      opacity: allDone ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: allDone ? null : _onCheckIn,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: allDone
                ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                : checkedIn
                    ? const LinearGradient(colors: [Colors.orange, Color(0xFFE65100)])
                    : const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryLight]),
            boxShadow: allDone
                ? []
                : [
                    BoxShadow(
                      color: (checkedIn ? Colors.orange : AppTheme.primaryColor).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                allDone
                    ? Icons.check_circle
                    : checkedIn
                        ? Icons.exit_to_app
                        : Icons.fingerprint,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                allDone
                    ? '今日打卡已完成'
                    : checkedIn
                        ? '離場打卡'
                        : '入場打卡',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 每日考勤記錄卡片
  Widget _buildDailyRecordCard(String hours) {
    final dateStr = '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每日考勤記錄（$dateStr）', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            if (_loadingRecord)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_todayRecord == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('當日無打卡記錄', style: TextStyle(color: AppTheme.textSecondary))),
              )
            else ...[
              _buildRecordRow('入場時間', _checkInTimeStr ?? '--'),
              const SizedBox(height: 8),
              _buildRecordRow('離場時間', _checkOutTimeStr ?? '--'),
              const SizedBox(height: 8),
              _buildRecordRow('工作時長', hours),
              const Divider(),
              _buildRecordRow('打卡方式', _todayRecord!['checkInType'] == 'BLUETOOTH' ? '藍牙定位 (BLE)' : 'GPS 定位'),
              _buildRecordRow('地盤', _siteName ?? '--'),
            ],
          ],
        ),
      ),
    );
  }

  /// 本月考勤日曆
  Widget _buildMonthlyCalendar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 月份切換標題列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                ),
                Text(_calendarMonthStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 星期標題
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text('一', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('二', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('三', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('四', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('五', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('六', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                Text('日', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),

            // 日曆網格
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  /// 日曆網格
  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    // 星期一到星期日：1=Mon,...,7=Sun
    final startWeekday = firstDay.weekday;
    final totalCells = ((startWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNum = index - (startWeekday - 1) + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final isToday = _isToday(_calendarMonth.year, _calendarMonth.month, dayNum);
        final isSelected = _selectedDate.year == _calendarMonth.year &&
            _selectedDate.month == _calendarMonth.month &&
            _selectedDate.day == dayNum;
        final hasRecord = _monthlyDays.contains(dayNum);
        final isWeekend = _getWeekday(_calendarMonth.year, _calendarMonth.month, dayNum) >= 6;

        return GestureDetector(
          onTap: () => _onDaySelected(dayNum),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : hasRecord
                      ? AppTheme.successColor.withOpacity(0.8)
                      : isWeekend
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasRecord || isToday ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : hasRecord
                          ? Colors.white
                          : isWeekend
                              ? Colors.grey
                              : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 判斷是否為今天
  bool _isToday(int year, int month, int day) {
    final now = DateTime.now();
    return now.year == year && now.month == month && now.day == day;
  }

  /// 獲取某天的星期（1=周一,...,7=周日）
  int _getWeekday(int year, int month, int day) {
    return DateTime(year, month, day).weekday;
  }

  /// 計算工時
  String _calcHours(dynamic checkIn, dynamic checkOut) {
    if (checkIn == null || checkOut == null) return '--';
    try {
      final inTime = checkIn is String ? DateTime.parse(checkIn) : checkIn;
      final outTime = checkOut is String ? DateTime.parse(checkOut) : checkOut;
      final duration = (outTime as DateTime).difference(inTime as DateTime);
      final h = duration.inHours;
      final m = duration.inMinutes.remainder(60);
      return '${h}小時${m}分鐘';
    } catch (_) {
      return '--';
    }
  }

  /// 記錄行
  Widget _buildRecordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
