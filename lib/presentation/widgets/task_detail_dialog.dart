/// 任务详情弹窗组件
///
/// 用于显示压缩任务的详细信息，包括：
/// - 文件名和压缩前后大小对比
/// - 压缩比例
/// - 视频时长和分辨率信息
/// - 操作按钮（打开文件夹、保存到相册等）
///
/// 支持桌面端和移动端两种显示模式。
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/compress_task.dart';
import 'video_player_page.dart';

/// 任务详情弹窗/底部表单组件
///
/// 根据平台显示不同的UI样式：
/// - 桌面端：使用AlertDialog弹窗
/// - 移动端：使用ModalBottomSheet底部表单
class TaskDetailDialog extends StatelessWidget {
  /// 要显示详情的压缩任务
  final CompressTask task;

  /// 是否为桌面端模式
  final bool isDesktop;

  /// 打开文件夹的回调函数（桌面端使用）
  final VoidCallback? onOpenFolder;

  /// 保存到相册的回调函数（移动端使用）
  final VoidCallback? onSaveToGallery;

  const TaskDetailDialog({
    super.key,
    required this.task,
    this.isDesktop = false,
    this.onOpenFolder,
    this.onSaveToGallery,
  });

  /// 格式化字节大小为可读字符串
  ///
  /// [bytes] - 字节数
  /// 返回格式化后的字符串，如 "1.5 MB" 或 "256 KB"
  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 构建详情行组件
  ///
  /// [label] - 标签文本
  /// [value] - 值文本
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDesktop
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDesktop ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建大小信息组件
  ///
  /// [label] - 标签文本（如 "Before" 或 "After"）
  /// [size] - 大小字符串
  /// [isHighlight] - 是否高亮显示（压缩后的大小通常高亮）
  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: isDesktop
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text(size,
            style: TextStyle(
              color: isHighlight
                  ? AppColors.success
                  : (isDesktop ? Colors.white : AppColors.textPrimary),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  /// 播放压缩后的视频
  ///
  /// 跳转到全屏视频播放页面
  void _playVideo(BuildContext context) {
    final path = task.outputPath;
    if (path == null || path.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(videoPath: path),
      ),
    );
  }

  /// 打开文件所在位置
  ///
  /// 根据不同平台使用不同的命令：
  /// - macOS: 使用 `open -R` 命令
  /// - Windows: 使用 `explorer /select` 命令
  /// - Linux: 使用 `xdg-open` 命令打开所在目录
  void _openFileLocation() {
    final path = task.outputPath;
    if (path == null || path.isEmpty) return;
    if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', ['/select,$path']);
    } else if (Platform.isLinux) {
      final lastIndex = path.lastIndexOf('/');
      if (lastIndex > 0) {
        final dir = path.substring(0, lastIndex);
        Process.run('xdg-open', [dir]);
      }
    }
  }

  /// 静态方法：显示任务详情弹窗
  ///
  /// [context] - 上下文
  /// [task] - 要显示的压缩任务
  /// [isDesktop] - 是否为桌面端模式
  /// [onOpenFolder] - 打开文件夹回调
  /// [onSaveToGallery] - 保存到相册回调
  static void show(
    BuildContext context, {
    required CompressTask task,
    bool isDesktop = false,
    VoidCallback? onOpenFolder,
    VoidCallback? onSaveToGallery,
  }) {
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => TaskDetailDialog(
          task: task,
          isDesktop: true,
          onOpenFolder: onOpenFolder,
          onSaveToGallery: onSaveToGallery,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          top: false,
          child: TaskDetailDialog(
            task: task,
            isDesktop: false,
            onOpenFolder: onOpenFolder,
            onSaveToGallery: onSaveToGallery,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.video.name ?? '',
          style: TextStyle(
            color: isDesktop ? Colors.white : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _buildSizeInfo('Before', task.video.sizeFormatted),
            ),
            Expanded(child: Container()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_forward,
                      color: AppColors.error, size: 20),
                  const SizedBox(height: 4),
                  Text('-${task.compressionRatio.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(child: Container()),
            Align(
              alignment: Alignment.centerRight,
              child: _buildSizeInfo('After', _formatSize(task.compressedSize),
                  isHighlight: true),
            ),
          ],
        ),
        if (task.video.duration != null ||
            task.originalResolution.isNotEmpty ||
            task.compressedResolution.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (task.video.duration != null)
            _buildDetailRow('Duration', task.video.durationFormatted),
          if (task.originalResolution.isNotEmpty)
            _buildDetailRow('Original Resolution', task.originalResolution),
          if (task.compressedResolution.isNotEmpty)
            _buildDetailRow('Compressed Resolution', task.compressedResolution),
        ],
        const SizedBox(height: 20),
        _buildActions(context),
      ],
    );

    if (isDesktop) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        content: SizedBox(width: 400, child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }

  /// 构建操作按钮区域
  ///
  /// 桌面端显示"打开文件夹"按钮
  /// 移动端显示"保存到相册"按钮
  Widget _buildActions(BuildContext context) {
    if (isDesktop) {
      return ElevatedButton.icon(
        onPressed: _openFileLocation,
        icon: const Icon(Icons.folder_open, size: 18),
        label: const Text('Open Folder'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    if (!isDesktop && onSaveToGallery != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onSaveToGallery,
          icon: const Icon(Icons.save_alt, size: 18),
          label: const Text('Save to Gallery'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
