import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/animated_entry_list.dart';
import '../../../data/models/compress_task.dart';
import '../../../data/models/video_info.dart';
import '../../../data/models/compress_config.dart';
import '../../../services/ffmpeg_service.dart';
import '../../pages/local_compress/local_compress_page.dart';
import '../../pages/local_compress/local_compress_bloc.dart';
import '../../pages/local_compress/local_compress_state.dart';
import '../../pages/local_compress/local_compress_event.dart';
import '../../pages/history/history_bloc.dart';
import '../../pages/history/history_state.dart';
import '../../pages/settings/settings_bloc.dart';
import '../../pages/settings/settings_state.dart';
import '../../widgets/video_player_page.dart';
import '../../widgets/video_list_item.dart';
import '../../widgets/task_detail_dialog.dart';
import 'home_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return const _DesktopHomePage();
    }
    return const LocalCompressPage();
  }
}

class _DesktopHomePage extends StatelessWidget {
  const _DesktopHomePage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Row(
            children: [
              _buildSidebar(context, state),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),
              Expanded(
                child: IndexedStack(
                  index: state.currentIndex,
                  children: const [
                    _DesktopCompressPage(),
                    _DesktopHistoryPage(),
                    _DesktopSettingsPage(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, HomeState state) {
    return Container(
      width: 220,
      color: const Color(0xFF252526),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Row(
              children: [
                Icon(Icons.compress, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Video Compressor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(context, Icons.home_outlined, Icons.home, 'Home',
                    0, state.currentIndex == 0),
                _buildNavItem(context, Icons.history_outlined, Icons.history,
                    'History', 1, state.currentIndex == 1),
                _buildNavItem(context, Icons.settings_outlined, Icons.settings,
                    'Settings', 2, state.currentIndex == 2),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, IconData activeIcon,
      String label, int index, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.7),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          context.read<HomeBloc>().add(HomeTabChanged(index));
          if (index == 1) context.read<HistoryBloc>().add(LoadHistory());
          if (index == 2) context.read<SettingsBloc>().add(LoadSettings());
        },
      ),
    );
  }
}

class _DesktopCompressPage extends StatefulWidget {
  const _DesktopCompressPage();

  @override
  State<_DesktopCompressPage> createState() => _DesktopCompressPageState();
}

class _DesktopCompressPageState extends State<_DesktopCompressPage> {
  bool _dragging = false;
  final Set<String> _animatedKeys = {};

  @override
  Widget build(BuildContext context) {
    final ffmpegService = context.read<FFmpegService>();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: DropTarget(
        onDragEntered: (details) {
          setState(() => _dragging = true);
        },
        onDragExited: (details) {
          setState(() => _dragging = false);
        },
        onDragDone: (details) {
          setState(() => _dragging = false);
          _handleDroppedFiles(details.files, context);
        },
        child: BlocBuilder<LocalCompressBloc, LocalCompressState>(
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Videos',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600)),
                          if (state.hasVideos)
                            TextButton.icon(
                              onPressed: state.isCompressing
                                  ? null
                                  : () => _selectVideos(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add More'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: state.hasVideos
                          ? _buildVideoList(
                              context, state, ffmpegService, _animatedKeys)
                          : _buildEmptyState(context),
                    ),
                    if (state.hasVideos) _buildBottomBar(context, state),
                  ],
                ),
                if (_dragging)
                  Positioned.fill(
                    child: Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.file_download,
                              size: 64,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Drop videos here',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleDroppedFiles(List<dynamic> files, BuildContext context) {
    const videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v'
    ];

    final videoPaths = <Map<String, dynamic>>[];
    for (final file in files) {
      final path = file.path as String?;
      if (path != null) {
        final lowerPath = path.toLowerCase();
        if (videoExtensions.any((ext) => lowerPath.endsWith(ext))) {
          videoPaths.add({'path': path});
        }
      }
    }

    if (videoPaths.isNotEmpty && mounted) {
      context.read<LocalCompressBloc>().add(SelectVideos(videoPaths));
    }
  }
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
          child: const Icon(Icons.video_library_outlined,
              size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        const Text('No Videos Selected',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('Click below to select videos for compression',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _selectVideos(context),
          icon: const Icon(Icons.folder_open, size: 20),
          label: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text('Select Videos', style: TextStyle(fontSize: 15)),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

Widget _buildVideoList(
  BuildContext context,
  LocalCompressState state,
  FFmpegService ffmpegService,
  Set<String> animatedKeys,
) {
  final videos = state.selectedVideos;
  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    itemCount: videos.length,
    itemBuilder: (context, index) {
      final video = videos[index];
      final task =
          state.tasks.where((t) => t.video.path == video.path).firstOrNull;
      final bitrateWarning = state.config.getWarningMessage(video.bitrate);

      return AnimatedEntryItem(
        itemKey: video.path,
        index: index,
        hasAnimated: (key) => animatedKeys.contains(key),
        markAsAnimated: (key) => animatedKeys.add(key),
        child: _DeletableVideoItem(
          key: ValueKey(video.path),
          video: video,
          task: task,
          ffmpegService: ffmpegService,
          bitrateWarning: bitrateWarning.isNotEmpty ? bitrateWarning : null,
          onTapThumbnail: () => _playVideo(context, video.path),
          onTapDetail: task != null && task.isComplete
              ? () => _showTaskDetail(context, task)
              : null,
          onDelete: () => _removeVideo(context, video, task, animatedKeys),
        ),
      );
    },
  );
}

/// 可删除的视频项（带右滑删除动画）
class _DeletableVideoItem extends StatefulWidget {
  final VideoInfo video;
  final CompressTask? task;
  final FFmpegService ffmpegService;
  final String? bitrateWarning;
  final VoidCallback? onTapThumbnail;
  final VoidCallback? onTapDetail;
  final VoidCallback? onDelete;

  const _DeletableVideoItem({
    super.key,
    required this.video,
    this.task,
    required this.ffmpegService,
    this.bitrateWarning,
    this.onTapThumbnail,
    this.onTapDetail,
    this.onDelete,
  });

  @override
  State<_DeletableVideoItem> createState() => _DeletableVideoItemState();
}

class _DeletableVideoItemState extends State<_DeletableVideoItem>
    with SingleTickerProviderStateMixin {
  bool _isDeleting = false;
  double? _itemWidth;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _sizeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDelete() {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    _controller.forward().then((_) {
      widget.onDelete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = VideoListItem(
      video: widget.video,
      task: widget.task,
      ffmpegService: widget.ffmpegService,
      bitrateWarning: widget.bitrateWarning,
      isDesktop: true,
      onTapThumbnail: widget.onTapThumbnail,
      onTapDetail: widget.onTapDetail,
      onDelete: _isDeleting ? null : _handleDelete,
    );

    if (!_isDeleting) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _itemWidth = constraints.maxWidth;
          return item;
        },
      );
    }

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axis: Axis.vertical,
      axisAlignment: -1.0,
      child: SizedBox(
        width: _itemWidth,
        child: ClipRect(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: item,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildBottomBar(BuildContext context, LocalCompressState state) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF252526),
      border:
          Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: state.isCompressing
              ? null
              : () =>
                  context.read<LocalCompressBloc>().add(const StartCompress()),
          icon: const Icon(Icons.compress, size: 18),
          label: Text(
              state.isCompressing ? 'Compressing...' : 'Start Compression'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
}

void _selectVideos(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: true,
    withData: false,
  );
  if (result != null && result.files.isNotEmpty && context.mounted) {
    final paths = result.paths.whereType<String>().toList();
    if (paths.isNotEmpty) {
      // 桌面端不需要缩略图，VideoListItem 会使用 FFmpeg 获取
      final videoDataList = paths.map((path) => {'path': path}).toList();
      context.read<LocalCompressBloc>().add(SelectVideos(videoDataList));
    }
  }
}

void _playVideo(BuildContext context, String path) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoPath: path)));
}

void _showTaskDetail(BuildContext context, CompressTask task) {
  TaskDetailDialog.show(context, task: task, isDesktop: true);
}

void _removeVideo(
    BuildContext context, video, CompressTask? task, Set<String> animatedKeys) {
  animatedKeys.remove(video.path);
  if (task != null && task.isRunning) {
    context.read<LocalCompressBloc>().add(CancelCompress(task.id));
  } else if (task != null) {
    context.read<LocalCompressBloc>().add(RemoveTask(task.id));
  }
  context.read<LocalCompressBloc>().add(RemoveSelectedVideo(video.path));
}

class _DesktopHistoryPage extends StatelessWidget {
  const _DesktopHistoryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compression History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    if (state.items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _showClearConfirmation(context),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Clear All'),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: state.items.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryGrid(state.items),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No compression history',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid(List<HistoryItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardWidth = 320.0;
        const spacing = 16.0;
        final crossAxisCount =
            (constraints.maxWidth / cardWidth).floor().clamp(1, 4);
        final actualCardWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * spacing - 48) /
                crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: spacing,
            runSpacing: 12,
            children: items
                .map((item) => SizedBox(
                      width: actualCardWidth,
                      child: _buildHistoryCard(context, item),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryItem item) {
    return GestureDetector(
      onTap: () => _showHistoryDetail(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2D2D2D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildSizeInfo(
                        'Before', _formatSize(item.originalSize)),
                  ),
                  Expanded(child: Container()),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: AppColors.error, size: 16),
                      const SizedBox(height: 2),
                      Text('-${item.compressionRatio.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 10)),
                    ],
                  ),
                  Expanded(child: Container()),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildSizeInfo(
                        'After', _formatSize(item.compressedSize),
                        isHighlight: true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_formatDate(item.compressedAt),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetail(BuildContext context, HistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildDetailSizeInfo(
                        'Before', _formatSize(item.originalSize)),
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
                        Text('-${item.compressionRatio.toStringAsFixed(1)}%',
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
                    child: _buildDetailSizeInfo(
                        'After', _formatSize(item.compressedSize),
                        isHighlight: true),
                  ),
                ],
              ),
              if (item.originalResolution.isNotEmpty ||
                  item.compressedResolution.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (item.originalResolution.isNotEmpty)
                  _buildDetailRow(
                      'Original Resolution', item.originalResolution),
                if (item.compressedResolution.isNotEmpty)
                  _buildDetailRow(
                      'Compressed Resolution', item.compressedResolution),
              ],
              const SizedBox(height: 12),
              _buildDetailRow('Compressed At', _formatDate(item.compressedAt)),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: item.outputPath.isNotEmpty
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoPlayerPage(videoPath: item.outputPath),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: item.outputPath.isNotEmpty
                        ? () => _openFileLocation(item.outputPath)
                        : null,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open Folder'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSizeInfo(String label, String size,
      {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        const SizedBox(height: 4),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _openFileLocation(String path) {
    if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', ['/select,$path']);
    } else if (Platform.isLinux) {
      final lastIndex = path.lastIndexOf('/');
      if (lastIndex > 0) {
        Process.run('xdg-open', [path.substring(0, lastIndex)]);
      }
    }
  }

  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        const SizedBox(height: 2),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title:
            const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear all history?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(ClearHistory());
              Navigator.pop(context);
            },
            child:
                const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DesktopSettingsPage extends StatelessWidget {
  const _DesktopSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  _buildSettingsCard(
                    title: 'Default Settings',
                    children: [
                      _buildDropdownRow('Default Quality', state.defaultQuality,
                          const ['Low', 'Medium', 'High'], (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(SetDefaultQuality(value));
                        }
                      }),
                      _buildDropdownRow(
                          'Default Resolution',
                          state.defaultResolution,
                          const ['480P', '720P', '1080P', 'Original'], (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(SetDefaultResolution(value));
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsCard(
                    title: 'Storage',
                    children: [
                      _buildInfoRow(
                          'Output Directory',
                          state.outputDirectory.isEmpty
                              ? 'Loading...'
                              : state.outputDirectory),
                      _buildActionRow('Clear Cache',
                          'Cache: ${_formatCacheSize(state.cacheSize)}', () {
                        context.read<SettingsBloc>().add(ClearCache());
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cache cleared')));
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsCard(
                    title: 'About',
                    children: [
                      _buildInfoRow('Version', '1.0.0'),
                      _buildInfoRow('Build', '2026.2'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(
      {required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF2D2D2D),
              underline: const SizedBox(),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
              ],
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  String _formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
