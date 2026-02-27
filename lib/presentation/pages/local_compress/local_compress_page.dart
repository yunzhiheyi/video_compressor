import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/compress_task.dart';
import '../../../services/ffmpeg_service.dart';
import '../../../utils/app_toast.dart';
import '../../widgets/video_picker_page.dart';
import '../../widgets/video_player_page.dart';
import '../../widgets/video_list_item.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../widgets/animated_entry_list.dart';
import '../history/history_bloc.dart';
import '../history/history_state.dart';
import '../settings/settings_bloc.dart';
import '../settings/settings_state.dart';
import 'local_compress_bloc.dart';
import 'local_compress_event.dart';
import 'local_compress_state.dart';

/// 移动端主页面
class LocalCompressPage extends StatefulWidget {
  const LocalCompressPage({super.key});

  @override
  State<LocalCompressPage> createState() => _LocalCompressPageState();
}

class _LocalCompressPageState extends State<LocalCompressPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _VideoCompressPage(),
                _HistoryPage(),
                _SettingsPage(),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _currentIndex == 0
                    ? 'Video Compressor'
                    : _currentIndex == 1
                        ? 'History'
                        : 'Settings',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabButton(Icons.home_outlined, Icons.home, 'Home', 0),
              _buildTabButton(
                  Icons.history_outlined, Icons.history, 'History', 1),
              _buildTabButton(
                  Icons.settings_outlined, Icons.settings, 'Settings', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
      IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = index);
          if (index == 1) context.read<HistoryBloc>().add(LoadHistory());
          if (index == 2) context.read<SettingsBloc>().add(LoadSettings());
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 视频压缩页面
class _VideoCompressPage extends StatefulWidget {
  const _VideoCompressPage();

  @override
  State<_VideoCompressPage> createState() => _VideoCompressPageState();
}

class _VideoCompressPageState extends State<_VideoCompressPage>
    with WidgetsBindingObserver {
  final Set<String> _animatedKeys = {};

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
      // 应用恢复时检查运行中的任务
      context.read<LocalCompressBloc>().add(const CheckRunningTasks());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalCompressBloc, LocalCompressState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(child: _buildContent(context, state)),
            if (state.hasVideos) _buildBottomBar(context, state),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, LocalCompressState state) {
    if (!state.hasVideos) {
      return _buildEmptyState(context);
    }
    return _buildVideoList(context, state);
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
          const Text(
            AppStrings.noVideoSelected,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _selectVideos(context),
            icon: const Icon(Icons.folder_open),
            label: const Text(AppStrings.selectVideo),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(BuildContext context, LocalCompressState state) {
    final ffmpegService = context.read<FFmpegService>();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.selectedVideos.length,
      itemBuilder: (context, index) {
        final video = state.selectedVideos[index];
        final task =
            state.tasks.where((t) => t.video.path == video.path).firstOrNull;
        final bitrateWarning = state.config.getWarningMessage(video.bitrate);

        return AnimatedEntryItem(
          itemKey: video.path,
          index: index,
          hasAnimated: (key) => _animatedKeys.contains(key),
          markAsAnimated: (key) => _animatedKeys.add(key),
          animationDirection: AnimationDirection.vertical,
          child: VideoListItem(
            video: video,
            task: task,
            ffmpegService: ffmpegService,
            bitrateWarning: bitrateWarning.isNotEmpty ? bitrateWarning : null,
            isDesktop: false,
            onTapThumbnail: () => _playVideo(context, video.path),
            onTapDetail: task != null && task.isComplete
                ? () => _showTaskDetail(context, task)
                : null,
            onDelete: () => _removeVideo(context, video, task, state),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, LocalCompressState state) {
    final pendingCount = state.selectedVideos
        .where((v) => !state.tasks.any((t) => t.video.path == v.path))
        .length;

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
                    state.isCompressing ? null : () => _selectVideos(context),
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

  void _selectVideos(BuildContext context) async {
    final hasPermission = await VideoPickerPage.checkPermission();
    if (!context.mounted) return;

    if (!hasPermission) {
      AppToast.error(context, 'Please grant photo library access');
      return;
    }

    final videoDataList = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPickerPage(
          maxCount: 10,
          ffmpegService: context.read<FFmpegService>(),
        ),
        fullscreenDialog: true,
      ),
    );

    if (videoDataList != null && videoDataList.isNotEmpty && context.mounted) {
      context.read<LocalCompressBloc>().add(SelectVideos(videoDataList));
    }
  }

  void _playVideo(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(videoPath: path),
      ),
    );
  }

  void _showTaskDetail(BuildContext context, CompressTask task) {
    TaskDetailDialog.show(
      context,
      task: task,
      isDesktop: false,
      onSaveToGallery: () => _saveToGallery(context, task),
    );
  }

  void _removeVideo(BuildContext context, video, CompressTask? task,
      LocalCompressState state) {
    _animatedKeys.remove(video.path);
    if (task != null && task.isRunning) {
      context.read<LocalCompressBloc>().add(CancelCompress(task.id));
    } else if (task != null) {
      context.read<LocalCompressBloc>().add(RemoveTask(task.id));
    }
    context.read<LocalCompressBloc>().add(RemoveSelectedVideo(video.path));
  }

  Future<void> _saveToGallery(BuildContext context, CompressTask task) async {
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
}

/// 历史记录页面
class _HistoryPage extends StatelessWidget {
  const _HistoryPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        if (state.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('No compression history',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: state.items.length,
          itemBuilder: (context, index) =>
              _buildHistoryItem(context, state.items[index]),
        );
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, HistoryItem item) {
    return GestureDetector(
      onTap: () => _showDetail(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      _buildSizeInfo('Before', _formatSize(item.originalSize)),
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
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  void _showDetail(BuildContext context, HistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 大小对比
              Row(
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSizeInfo(
                          'Before', _formatSize(item.originalSize))),
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
                    child: _buildSizeInfo(
                        'After', _formatSize(item.compressedSize),
                        isHighlight: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 详细信息表格
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildHistoryCompareRow(
                      'Size',
                      _formatSize(item.originalSize),
                      _formatSize(item.compressedSize),
                    ),
                    if (item.originalResolution.isNotEmpty)
                      _buildHistoryCompareRow(
                        'Resolution',
                        item.originalResolution,
                        item.compressedResolution.isNotEmpty
                            ? item.compressedResolution
                            : item.originalResolution,
                      ),
                    _buildHistoryCompareRow(
                      'Bitrate',
                      item.originalBitrateFormatted,
                      item.compressedBitrateFormatted,
                    ),
                    _buildHistoryCompareRow(
                      'Frame Rate',
                      item.frameRateFormatted,
                      item.frameRateFormatted,
                    ),
                    if (item.duration > 0)
                      _buildHistorySingleRow(
                          'Duration', item.durationFormatted),
                    _buildHistorySingleRow(
                        'Compressed At', _formatDate(item.compressedAt)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: item.outputPath.isNotEmpty
                        ? () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => VideoPlayerPage(
                                        videoPath: item.outputPath)));
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
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: item.outputPath.isNotEmpty
                          ? () => _saveToGallery(context, item)
                          : null,
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text('Save to Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCompareRow(String label, String before, String after) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              before,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Icon(Icons.arrow_forward,
              color: AppColors.textSecondary, size: 14),
          Expanded(
            child: Text(
              after,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySingleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              )),
          Text(value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Future<void> _saveToGallery(BuildContext context, HistoryItem item) async {
    try {
      await Gal.putVideo(item.outputPath);
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.success(context, 'Video saved to gallery');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to save: $e');
      }
    }
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

/// 设置页面
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Default Settings', [
                _buildDropdownRow('Default Quality', state.defaultQuality,
                    const ['Low', 'Medium', 'High'], (value) {
                  if (value != null) {
                    context.read<SettingsBloc>().add(SetDefaultQuality(value));
                  }
                }),
                _buildDropdownRow('Default Resolution', state.defaultResolution,
                    const ['480P', '720P', '1080P', 'Original'], (value) {
                  if (value != null) {
                    context
                        .read<SettingsBloc>()
                        .add(SetDefaultResolution(value));
                  }
                }),
              ]),
              const SizedBox(height: 16),
              _buildSection('Storage', [
                _buildInfoRow(
                    'Output Directory',
                    state.outputDirectory.isEmpty
                        ? 'Loading...'
                        : state.outputDirectory),
                _buildActionRow('Clear Cache',
                    'Cache: ${_formatCacheSize(state.cacheSize)}', () {
                  context.read<SettingsBloc>().add(ClearCache());
                  AppToast.success(context, 'Cache cleared');
                }),
              ]),
              const SizedBox(height: 16),
              _buildSection('About', [
                _buildInfoRow('Version', '1.0.0'),
                _buildInfoRow('Build', '2026.2'),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          const Divider(color: AppColors.divider, height: 1),
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
          Text(label, style: const TextStyle(color: AppColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            style:
                                const TextStyle(color: AppColors.textPrimary)),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
              child: Text(value,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textAlign: TextAlign.right)),
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
                Text(label,
                    style: const TextStyle(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
