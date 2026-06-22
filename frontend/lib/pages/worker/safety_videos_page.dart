import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class SafetyVideosPage extends StatefulWidget {
  const SafetyVideosPage({super.key});

  @override
  State<SafetyVideosPage> createState() => _SafetyVideosPageState();
}

class _SafetyVideosPageState extends State<SafetyVideosPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getSafetyVideos();
      if (!mounted) return;
      setState(() {
        _videos = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  int _getWatchedCount() {
    int total = 0;
    for (final v in _videos) {
      if (v['completed'] == true) total++;
    }
    return total;
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _playVideo(Map<String, dynamic> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(
          video: video,
          onWatched: () {
            // 标记本地为已观看
            setState(() {
              video['completed'] = true;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchedCount = _getWatchedCount();
    final totalCount = _videos.length;

    return Scaffold(
      appBar: AppBar(title: const Text('安全培訓')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadVideos, child: const Text('重試')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 培训进度卡片
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
                          const Text('培訓進度',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            totalCount > 0 ? '$watchedCount/$totalCount' : '0/0',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (totalCount > 0)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: watchedCount / totalCount,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 8,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            totalCount > 0
                                ? '${(watchedCount / totalCount * 100).toInt()}% 已完成'
                                : '暫無影片',
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // 视频列表
                    Expanded(
                      child: _videos.isEmpty
                          ? const Center(child: Text('暫無安全培訓影片'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _videos.length,
                              itemBuilder: (context, index) {
                                final video = _videos[index];
                                final isCompleted =
                                    video['completed'] == true;
                                final isMandatory =
                                    video['mandatory'] == true;
                                final duration = video['duration'] as int? ?? 0;
                                final title =
                                    video['title'] as String? ?? '未命名影片';
                                final description =
                                    video['description'] as String?;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _playVideo(video),
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
                                                  color: Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                ),
                                              ),
                                              if (isCompleted)
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(2),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          AppTheme.successColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 12),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600),
                                                      ),
                                                    ),
                                                    if (isMandatory)
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme
                                                              .errorColor
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: const Text(
                                                          '必修',
                                                          style: TextStyle(
                                                              color: AppTheme
                                                                  .errorColor,
                                                              fontSize: 10),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (description != null &&
                                                    description.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    description,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme
                                                            .textSecondary),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                                if (duration > 0) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatDuration(duration),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme
                                                            .textSecondary),
                                                  ),
                                                ],
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

                    // 底部提醒
                    if (totalCount > 0 && watchedCount < totalCount)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: AppTheme.warningColor.withOpacity(0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.warningColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '您還有 ${totalCount - watchedCount} 個影片未觀看，未看完影片將限制打卡',
                                style: const TextStyle(
                                    color: AppTheme.warningColor, fontSize: 12),
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

/// 视频播放页面（全屏 Chewie 播放器）
class _VideoPlayerPage extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onWatched;

  const _VideoPlayerPage({
    required this.video,
    required this.onWatched,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  final _api = ApiService();
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  bool _hasMarkedCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final videoUrl = widget.video['videoUrl'] as String? ?? '';
    if (videoUrl.isEmpty) {
      setState(() => _error = '影片網址為空');
      return;
    }

    // 如果是相對路徑，拼接完整地址
    final fullUrl = videoUrl.startsWith('http')
        ? videoUrl
        : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$videoUrl';

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          bufferedColor: Colors.grey.shade300,
          handleColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey.shade200,
        ),
      );

      // 监听播放位置变化
      _videoController!.addListener(_onPositionChanged);

      if (!mounted) return;
      setState(() => _initialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '影片加載失敗：$e');
    }
  }

  void _onPositionChanged() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (_hasMarkedCompleted) return;

    final position = _videoController!.value.position.inSeconds;
    final duration = _videoController!.value.duration.inSeconds;

    // 观看到最后1秒即标记完成
    if (duration > 0 && position >= duration - 1) {
      _hasMarkedCompleted = true;
      _videoController!.removeListener(_onPositionChanged);

      final videoId = widget.video['id'] as int? ?? 0;
      if (videoId > 0) {
        _api.markVideoWatched(videoId, duration).then((_) {
          widget.onWatched();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onPositionChanged);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video['title'] as String? ?? '播放影片';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ],
              ),
            )
          : !_initialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Chewie(controller: _chewieController!),
                    ),
                    if (_hasMarkedCompleted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.successColor,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '觀看完成，即將返回',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
