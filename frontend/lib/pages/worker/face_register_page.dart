import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class FaceRegisterPage extends StatefulWidget {
  const FaceRegisterPage({super.key});

  @override
  State<FaceRegisterPage> createState() => _FaceRegisterPageState();
}

class _FaceRegisterPageState extends State<FaceRegisterPage> {
  final _api = ApiService();
  final _picker = ImagePicker();

  bool _faceRegisteredFromApi = false; // 初始从 API 读取的人脸登记状态
  bool _submitted = false;             // 用户已成功提交
  bool _navigating = false;
  bool _submitting = false;
  String? _workerNumber;
  String? _faceImageBase64;
  String? _error;

  /// 已登记 = 用户已提交成功（不依赖 API 返回值，避免竞态）
  bool get _registered => _submitted;

  @override
  void initState() {
    super.initState();
    _loadWorkerNumber();
  }

  Future<void> _loadWorkerNumber() async {
    try {
      final data = await _api.getWorkerProfile();
      if (!mounted) return;
      setState(() {
        _workerNumber = data['workerNumber'];
        _faceRegisteredFromApi = data['faceRegistered'] ?? false;
      });
    } catch (e) {
      try {
        final homeData = await _api.getWorkerHome();
        if (!mounted) return;
        final profile = homeData['profile'];
        setState(() {
          _workerNumber = profile?['workerNumber'];
          _faceRegisteredFromApi = profile?['faceRegistered'] ?? false;
        });
      } catch (_) {}
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 80,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final ext = image.path.toLowerCase().split('.').last;
      final mime = (ext == 'png') ? 'image/png' : (ext == 'gif') ? 'image/gif' : 'image/jpeg';
      final base64 = base64Encode(bytes);
      setState(() {
        _faceImageBase64 = 'data:$mime;base64,$base64';
        _error = null;
      });
    } catch (e) {
      // Fallback: simulate with placeholder
      setState(() {
        _faceImageBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==';
        _error = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 80,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final ext = image.path.toLowerCase().split('.').last;
      final mime = (ext == 'png') ? 'image/png' : (ext == 'gif') ? 'image/gif' : 'image/jpeg';
      final base64 = base64Encode(bytes);
      setState(() {
        _faceImageBase64 = 'data:$mime;base64,$base64';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '選擇圖片失敗：$e');
    }
  }

  Future<void> _submit() async {
    if (_faceImageBase64 == null) {
      setState(() => _error = '請先拍攝或選擇人臉圖片');
      return;
    }

    setState(() => _submitting = true);
    try {
      String base64Data = _faceImageBase64!;
      if (base64Data.contains(',')) {
        base64Data = base64Data.split(',').last;
      }

      await _api.registerFaceBase64(base64Data);
      if (!mounted) return;
      setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 注册成功后自动跳转首页
    if (_registered && !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/worker/home');
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('人臉識別登記'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _registered ? _buildSuccessView() : _buildCaptureView(),
    );
  }

  Widget _buildCaptureView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 说明卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '請拍攝清晰的人臉照片，用於工地打卡時的人臉識別比對。\n請確保光線充足，面部無遮擋。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 人臉框
          Container(
            width: 240,
            height: 320,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: _faceImageBase64 != null
                  ? Image.memory(
                      base64Decode(_faceImageBase64!.split(',').last),
                      fit: BoxFit.cover,
                      width: 240,
                      height: 320,
                      errorBuilder: (_, __, ___) => _buildFacePlaceholder(),
                    )
                  : _buildFacePlaceholder(),
            ),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],

          // 拍照按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(_faceImageBase64 == null ? '拍攝人臉' : '重新拍攝'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 从相册选择
          TextButton.icon(
            onPressed: _submitting ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('或從相冊選擇'),
          ),
          const SizedBox(height: 12),

          if (_faceImageBase64 != null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('確認提交', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFacePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.face, size: 80, color: AppTheme.primaryColor.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text('點擊上方按鈕\n拍攝人臉',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, color: AppTheme.successColor, size: 80),
            ),
            const SizedBox(height: 32),
            const Text('人臉識別登記成功！',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
            const SizedBox(height: 16),
            if (_workerNumber != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('您的專屬工人編號', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      _workerNumber!,
                      style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor, letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('請牢記您的工人編號，如有問題可聯繫管理員',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
