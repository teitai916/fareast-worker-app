import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';

class SafetyVideosPage extends StatefulWidget {
  const SafetyVideosPage({super.key});

  @override
  State<SafetyVideosPage> createState() => _SafetyVideosPageState();
}

class _SafetyVideosPageState extends State<SafetyVideosPage> {
  final List<Map<String, dynamic>> _videos = [
    {'title': '工地安全守則入門', 'duration': '15:30', 'required': true, 'watched': true},
    {'title': '高空作業安全須知', 'duration': '12:45', 'required': true, 'watched': true},
    {'title': '電動工具安全操作', 'duration': '18:20', 'required': true, 'watched': false},
    {'title': '防火安全與應急處理', 'duration': '10:15', 'required': false, 'watched': false},
    {'title': '個人防護裝備(PPE)使用指引', 'duration': '8:30', 'required': true, 'watched': false},
  ];

  @override
  Widget build(BuildContext context) {
    final watchedCount = _videos.where((v) => v['watched'] as bool).length;

    return Scaffold(
      appBar: AppBar(title: const Text('安全培訓')),
      body: Column(
        children: [
          // Progress card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('培訓進度', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '$watchedCount/${_videos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: watchedCount / _videos.length,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(watchedCount / _videos.length * 100).toInt()}% 已完成',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Video list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('正在播放：${video['title']}')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                                ),
                              ),
                              if (video['watched'] as bool)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        video['title'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (video['required'] as bool)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('必修', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(video['duration'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Watch reminder
          if (watchedCount < _videos.length)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.warningColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '您還有 ${_videos.length - watchedCount} 個影片未觀看，未看完影片將限制打卡',
                      style: const TextStyle(color: AppTheme.warningColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
