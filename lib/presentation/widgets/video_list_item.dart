/// 通用视频列表项组件
///
/// 用于显示视频列表中的单个视频项，支持：
/// - 桌面端和移动端两种布局
/// - 缩略图显示（桌面端使用FFmpeg提取，移动端使用系统缩略图）
/// - 压缩任务状态显示（排队中、进行中、完成、失败）
/// - 桌面端：点击删除按钮删除
/// - 移动端：左滑删除
///
/// 使用方式：
/// ```dart
/// VideoListItem(
///   video: videoInfo,
///   task: compressTask,
///   ffmpegService: ffmpegService,
///   isDesktop: true,
///   onTapThumbnail: () => playVideo(),
///   onDelete: () => removeVideo(),
/// )
/// ```
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/compress_task.dart';
import '../../../data/models/video_info.dart';
import '../../../services/ffmpeg_service.dart';

/// 通用视频列表项组件
class VideoListItem extends StatefulWidget {
  /// 视频信息
  final VideoInfo video;

  /// 关联的压缩任务（可选）
  final CompressTask? task;

  /// FFmpeg服务（用于提取缩略图）
  final FFmpegService ffmpegService;

  /// 码率警告信息（当原视频码率较低时显示）
  final String? bitrateWarning;

  /// 点击缩略图回调
  final VoidCallback? onTapThumbnail;

  /// 点击详情回调（压缩完成后点击查看详情）
  final VoidCallback? onTapDetail;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 是否为桌面端布局
  final bool isDesktop;

  const VideoListItem({
    super.key,
    required this.video,
    required this.ffmpegService,
    this.task,
    this.bitrateWarning,
    this.onTapThumbnail,
    this.onTapDetail,
    this.onDelete,
    this.isDesktop = false,
  });

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem> {
  /// 缩略图数据
  Uint8List? _thumbnail;

  /// 是否正在加载缩略图
  bool _isLoadingThumbnail = false;

  /// 缩略图缓存（避免重复加载）
  static final Map<String, Uint8List?> _thumbnailCache = {};

  /// 正在加载中的路径集合（防止重复加载）
  static final Set<String> _loadingPaths = {};

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当视频路径变化时重新加载缩略图
    if (oldWidget.video.path != widget.video.path) {
      _thumbnail = null;
      _isLoadingThumbnail = false;
      _loadThumbnail();
    }
  }

  /// 加载缩略图
  ///
  /// 加载策略：
  /// 1. 移动端优先使用系统提供的缩略图
  /// 2. 桌面端使用FFmpeg提取第一帧
  /// 3. 使用静态缓存避免重复提取
  Future<void> _loadThumbnail() async {
    // 移动端优先使用已有的缩略图
    if (widget.video.thumbnailBytes != null) {
      setState(() => _thumbnail = widget.video.thumbnailBytes);
      return;
    }

    // 桌面端使用 FFmpeg 获取缩略图
    if (!widget.isDesktop) return;

    // 检查缓存
    if (_thumbnailCache.containsKey(widget.video.path)) {
      setState(() => _thumbnail = _thumbnailCache[widget.video.path]);
      return;
    }

    // 防止重复加载
    if (_loadingPaths.contains(widget.video.path)) return;
    _loadingPaths.add(widget.video.path);
    setState(() => _isLoadingThumbnail = true);

    try {
      final thumbnail =
          await widget.ffmpegService.extractThumbnail(widget.video.path);
      _thumbnailCache[widget.video.path] = thumbnail;
      if (mounted) {
        setState(() => _thumbnail = thumbnail);
      }
    } catch (e) {
      debugPrint('Thumbnail load failed: $e');
    } finally {
      _loadingPaths.remove(widget.video.path);
      if (mounted) {
        setState(() => _isLoadingThumbnail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.task?.isRunning ?? false;
    final progress = widget.task?.progress ?? 0.0;
    final content = _buildContent();

    // 桌面端布局
    if (widget.isDesktop) {
      return GestureDetector(
        onTap: widget.task != null && widget.task!.isComplete
            ? widget.onTapDetail
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF2D2D2D),
                  child: content,
                ),
                if (isRunning) _buildProgressBar(progress),
              ],
            ),
          ),
        ),
      );
    }

    // 移动端布局（支持左滑删除）
    return Dismissible(
      key: Key(widget.video.path),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => true,
      onDismissed: (_) => widget.onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: widget.task != null && widget.task!.isComplete
            ? widget.onTapDetail
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: AppColors.surface,
                  child: content,
                ),
                if (isRunning) _buildProgressBar(progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建主要内容（缩略图 + 信息 + 操作按钮）
  Widget _buildContent() {
    final isRunning = widget.task?.isRunning ?? false;
    final progress = widget.task?.progress ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽度不足时不渲染（避免动画期间的overflow）
        if (constraints.maxWidth < 200) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: _buildThumbnail(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfo()),
                  Container(
                    height: 65,
                    alignment: Alignment.center,
                    child: _buildTrailing(),
                  ),
                ],
              ),
              if (isRunning) _buildProgressWatermark(progress),
            ],
          ),
        );
      },
    );
  }

  /// 构建缩略图
  Widget _buildThumbnail() {
    return GestureDetector(
      onTap: widget.onTapThumbnail,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: widget.isDesktop ? 120 : 100,
          height: widget.isDesktop ? 80 : 70,
          color: AppColors.primary.withValues(alpha: 0.1),
          child: Stack(
            children: [
              // 加载中状态
              if (_isLoadingThumbnail)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_thumbnail != null)
                Positioned.fill(
                  child: Image.memory(_thumbnail!, fit: BoxFit.cover),
                ),
              // 无缩略图时显示图标
              if (!_isLoadingThumbnail && _thumbnail == null)
                const Center(
                  child:
                      Icon(Icons.videocam, color: AppColors.primary, size: 28),
                ),
              // 视频大小 - 左上角
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7)
                        ]),
                  ),
                  child: Text(
                    widget.video.sizeFormatted,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              // 视频时长 - 右下角
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7)
                        ]),
                  ),
                  child: Text(
                    widget.video.durationFormatted,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              // 播放按钮
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建视频信息区域
  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频名称
          Text(
            widget.video.name ?? '',
            style: TextStyle(
              color: widget.isDesktop ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 码率警告
          if (widget.bitrateWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppColors.warning, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.bitrateWarning ?? '',
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          _buildTaskStatus(),
        ],
      ),
    );
  }

  /// 构建任务状态显示
  Widget _buildTaskStatus() {
    final task = widget.task;
    if (task == null) return const SizedBox.shrink();

    // 已完成：显示压缩比例
    if (task.isComplete) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Saved ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              TextSpan(
                text: '-${task.compressionRatio.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.error, fontSize: 11),
              ),
              TextSpan(
                text: ' (${_formatSize(task.compressedSize)})',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    // 失败：显示错误信息
    if (task.isFailed) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                task.errorMessage ?? 'Failed',
                style: const TextStyle(color: AppColors.error, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // 排队中
    if (task.isQueued) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Queued',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建进度水印（压缩中显示在右下角）
  Widget _buildProgressWatermark(double progress) {
    final percentage = (progress * 100).toStringAsFixed(0);
    return Positioned(
      right: 0,
      bottom: 0,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: percentage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: widget.isDesktop ? 24 : 18,
              ),
            ),
            TextSpan(
              text: '%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: widget.isDesktop ? 14 : 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建进度条（压缩中显示在底部）
  Widget _buildProgressBar(double progress) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  /// 构建尾部操作区域
  Widget _buildTrailing() {
    // 桌面端：显示删除按钮
    if (widget.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.task != null &&
              (widget.task!.isComplete ||
                  widget.task!.isFailed ||
                  widget.task!.isRunning ||
                  widget.task!.isQueued))
            _buildIconButton(
                icon: Icons.delete_outline, onTap: widget.onDelete),
          if (widget.task == null)
            _buildIconButton(
                icon: Icons.delete_outline, onTap: widget.onDelete),
        ],
      );
    }

    // 移动端：压缩完成后显示右箭头
    if (widget.task != null && widget.task!.isComplete) {
      return GestureDetector(
        onTap: widget.onTapDetail,
        child: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建图标按钮
  Widget _buildIconButton(
      {required IconData icon, Color? color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: color ??
                (widget.isDesktop
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// 格式化文件大小
  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
