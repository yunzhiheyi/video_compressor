import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/compress_task.dart';
import '../../data/models/video_info.dart';
import '../../services/ffmpeg_service.dart';
import '../../utils/app_toast.dart';
import '../pages/local_compress/local_compress_bloc.dart';
import '../pages/local_compress/local_compress_event.dart';
import '../pages/local_compress/local_compress_state.dart';
import '../widgets/video_picker_page.dart';
import '../widgets/video_player_page.dart';
import '../widgets/video_list_item.dart';
import '../widgets/task_detail_dialog.dart';
import '../widgets/animated_entry_list.dart';
import '../widgets/animated_removable_item.dart';
import 'video_overlay_player.dart';

enum VideoCompressStyle { mobile, desktop }

class VideoCompressContent extends StatefulWidget {
  final VideoCompressStyle style;
  final bool includeBottomBar;

  const VideoCompressContent({
    super.key,
    this.style = VideoCompressStyle.mobile,
    this.includeBottomBar = true,
  });

  @override
  State<VideoCompressContent> createState() => VideoCompressContentState();
}

class VideoCompressContentState extends State<VideoCompressContent>
    with WidgetsBindingObserver {
  final Set<String> _animatedKeys = {};
  final Map<String, GlobalKey<AnimatedRemovableItemState>> _removableItemKeys =
      {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LocalCompressBloc>().add(const CheckRunningTasks());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocalCompressBloc, LocalCompressState>(
      listenWhen: (previous, current) =>
          previous.toastMessage != current.toastMessage &&
          current.toastMessage != null,
      listener: (context, state) {
        if (state.toastMessage != null) {
          AppToast.show(context, state.toastMessage!);
          context.read<LocalCompressBloc>().add(const ClearToastMessage());
        }
      },
      child: BlocBuilder<LocalCompressBloc, LocalCompressState>(
        builder: (context, state) {
          if (!widget.includeBottomBar) {
            if (!state.hasVideos) {
              return _buildEmptyState(context);
            }
            return _buildVideoList(context, state);
          }

          return Column(
            children: [
              Expanded(
                child: !state.hasVideos
                    ? _buildEmptyState(context)
                    : _buildVideoList(context, state),
              ),
              if (state.hasVideos) _buildBottomBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noVideoSelected,
            style: TextStyle(
              color: widget.style == VideoCompressStyle.desktop
                  ? Colors.white
                  : AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.style == VideoCompressStyle.desktop
                ? 'Drop videos here or click below to select'
                : 'Click below to select videos for compression',
            style: TextStyle(
              color: widget.style == VideoCompressStyle.desktop
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => selectVideos(context),
            icon: const Icon(Icons.folder_open),
            label: Text(widget.style == VideoCompressStyle.desktop
                ? 'Select Videos'
                : AppStrings.selectVideo),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(BuildContext context, LocalCompressState state) {
    final ffmpegService = context.read<FFmpegService>();
    final padding = widget.style == VideoCompressStyle.desktop ? 24.0 : 12.0;

    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: state.selectedVideos.length,
      itemBuilder: (context, index) {
        final video = state.selectedVideos[index];
        final task =
            state.tasks.where((t) => t.video.path == video.path).firstOrNull;

        // 移动端点击缩略图时使用 overlay player 播放视频（带 Hero 动画）
        final onTapThumbnailWithRect = widget.style == VideoCompressStyle.mobile
            ? (VideoInfo v, Rect rect) => _playVideoWithOverlay(context, v, rect)
            : null;
        final onTapThumbnail = widget.style == VideoCompressStyle.desktop
            ? () => playVideo(context, video.path)
            : null;

        final listItem = VideoListItem(
          video: video,
          task: task,
          ffmpegService: ffmpegService,
          isDesktop: widget.style == VideoCompressStyle.desktop,
          onTapThumbnail: onTapThumbnail,
          onTapThumbnailWithRect: onTapThumbnailWithRect,
          onTapDetail: task != null && task.isComplete
              ? () => showTaskDetail(
                  context, task, widget.style == VideoCompressStyle.desktop)
              : null,
          onDelete: () => removeVideo(context, video, task),
          onRetry: task != null && (task.isFailed || task.isSkipped)
              ? () => context.read<LocalCompressBloc>().add(RetryTask(task.id))
              : null,
        );

        // 桌面端：包裹 AnimatedRemovableItem 实现删除动画
        if (widget.style == VideoCompressStyle.desktop) {
          _removableItemKeys[video.path] ??=
              GlobalKey<AnimatedRemovableItemState>();
          return AnimatedEntryItem(
            itemKey: video.path,
            index: index,
            hasAnimated: (key) => _animatedKeys.contains(key),
            markAsAnimated: (key) => _animatedKeys.add(key),
            animationDirection: AnimationDirection.vertical,
            child: AnimatedRemovableItem(
              key: _removableItemKeys[video.path],
              onRemove: () => _performRemove(context, video, task),
              child: listItem,
            ),
          );
        }

        // 移动端：使用 AnimatedEntryItem + Dismissible
        return AnimatedEntryItem(
          itemKey: video.path,
          index: index,
          hasAnimated: (key) => _animatedKeys.contains(key),
          markAsAnimated: (key) => _animatedKeys.add(key),
          animationDirection: AnimationDirection.vertical,
          child: listItem,
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, LocalCompressState state) {
    final pendingCount = state.selectedVideos
        .where((v) => !state.tasks.any((t) => t.video.path == v.path))
        .length;

    if (widget.style == VideoCompressStyle.desktop) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252526),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: state.isCompressing
                  ? null
                  : () => context
                      .read<LocalCompressBloc>()
                      .add(const StartCompress()),
              icon: const Icon(Icons.compress, size: 18),
              label: Text(
                  state.isCompressing ? 'Compressing...' : 'Start Compression'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pendingCount pending',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed:
                    state.isCompressing ? null : () => selectVideos(context),
                child: const Text('Add More'),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isCompressing || pendingCount == 0
                  ? null
                  : () => context
                      .read<LocalCompressBloc>()
                      .add(const StartCompress()),
              child: Text(
                state.isCompressing
                    ? AppStrings.compressing
                    : AppStrings.startCompress,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> selectVideos(BuildContext context) async {
    // Desktop: 直接打开文件选择器
    if (Platform.isMacOS) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return;

      final paths = result.paths.whereType<String>().toList();
      if (paths.isEmpty) return;

      // 获取视频元数据
      final ffmpegService = context.read<FFmpegService>();
      final videoDataList = <Map<String, dynamic>>[];

      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) continue;

        final info = await ffmpegService.getVideoInfo(path);
        videoDataList.add({
          'path': path,
          'name': info['name'],
          'size': info['size'],
          'width': info['width'],
          'height': info['height'],
          'duration': info['duration'],
          'bitrate': info['bitrate'],
          'frameRate': info['frameRate'],
          'rotation': info['rotation'],
        });
      }

      if (videoDataList.isNotEmpty && context.mounted) {
        context.read<LocalCompressBloc>().add(SelectVideos(videoDataList));
      }
      return;
    }

    // Mobile: 使用 VideoPickerPage
    final hasPermission = await VideoPickerPage.checkPermission();
    if (!context.mounted) return;

    if (!hasPermission) {
      AppToast.error(context, 'Please grant photo library access');
      return;
    }

    final videoDataList = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoPickerPage(
          maxCount: 10,
          ffmpegService: context.read<FFmpegService>(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end);
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: tween.animate(curvedAnimation),
            child: child,
          );
        },
        fullscreenDialog: true,
      ),
    );

    if (videoDataList != null && videoDataList.isNotEmpty && context.mounted) {
      context.read<LocalCompressBloc>().add(SelectVideos(videoDataList));
    }
  }

  static void playVideo(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(videoPath: path),
      ),
    );
  }

  /// 移动端使用 overlay player 播放视频
  ///
  /// [video] 视频信息
  /// [thumbnailRect] 缩略图在屏幕上的位置，用于 Hero 动画
  void _playVideoWithOverlay(
    BuildContext context,
    VideoInfo video,
    Rect thumbnailRect,
  ) {
    // 使用考虑旋转后的宽高比
    final aspectRatio = video.orientatedAspectRatio ?? 16 / 9;

    showVideoOverlay(
      context: context,
      videoPath: video.path,
      startRect: thumbnailRect,
      thumbnail: video.thumbnailBytes,
      aspectRatio: aspectRatio,
    );
  }

  static void showTaskDetail(BuildContext context, CompressTask task,
      [bool isDesktop = false]) {
    TaskDetailDialog.show(
      context,
      task: task,
      isDesktop: isDesktop,
      onSaveToGallery: isDesktop ? null : () => _saveToGallery(context, task),
    );
  }

  static Future<void> _saveToGallery(
      BuildContext context, CompressTask task) async {
    final path = task.outputPath;
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await Gal.putVideo(path);
        if (context.mounted) {
          Navigator.pop(context);
          AppToast.success(context, 'Video saved to gallery');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to save: $e');
      }
    }
  }

  void removeVideo(BuildContext context, video, CompressTask? task) {
    // 桌面端：先播放删除动画，再执行删除
    if (widget.style == VideoCompressStyle.desktop) {
      final key = _removableItemKeys[video.path];
      if (key?.currentState != null) {
        key!.currentState!.remove();
        return;
      }
    }
    // 移动端或动画 key 不存在：直接删除
    _performRemove(context, video, task);
  }

  void _performRemove(BuildContext context, video, CompressTask? task) {
    _animatedKeys.remove(video.path);
    _removableItemKeys.remove(video.path);
    if (task != null && task.isRunning) {
      context.read<LocalCompressBloc>().add(CancelCompress(task.id));
    } else if (task != null) {
      context.read<LocalCompressBloc>().add(RemoveTask(task.id));
    }
    context.read<LocalCompressBloc>().add(RemoveSelectedVideo(video.path));
  }
}
