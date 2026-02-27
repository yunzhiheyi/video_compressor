import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/video_compress_content.dart';
import '../../local_compress/local_compress_bloc.dart';
import '../../local_compress/local_compress_event.dart';
import '../../local_compress/local_compress_state.dart';
import '../../../../services/ffmpeg_service.dart';

class DesktopCompressPage extends StatefulWidget {
  const DesktopCompressPage({super.key});

  @override
  State<DesktopCompressPage> createState() => _DesktopCompressPageState();
}

class _DesktopCompressPageState extends State<DesktopCompressPage> {
  bool _dragging = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
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
          _handleDroppedFiles(details.files);
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
                          if (state.hasVideos && !_loading)
                            TextButton.icon(
                              onPressed: state.isCompressing
                                  ? null
                                  : () => _selectFiles(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add More'),
                            ),
                          if (_loading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: VideoCompressContent(
                        style: VideoCompressStyle.desktop,
                        includeBottomBar: false,
                      ),
                    ),
                    if (state.hasVideos) _buildBottomBar(context, state),
                  ],
                ),
                if (_dragging) _buildDropOverlay(),
                if (_loading && !_dragging) _buildLoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropOverlay() {
    return Positioned.fill(
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
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading video info...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDroppedFiles(List<dynamic> files) async {
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

    final videoPaths = <String>[];
    for (final file in files) {
      final path = file.path?.toString();
      if (path != null) {
        final lowerPath = path.toLowerCase();
        if (videoExtensions.any((ext) => lowerPath.endsWith(ext))) {
          videoPaths.add(path);
        }
      }
    }

    if (videoPaths.isEmpty) return;

    await _loadVideoInfo(videoPaths);
  }

  Future<void> _selectFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;

    await _loadVideoInfo(paths);
  }

  Future<void> _loadVideoInfo(List<String> paths) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final ffmpegService = context.read<FFmpegService>();
      final videoDataList = <Map<String, dynamic>>[];

      for (final path in paths) {
        // 检查文件是否存在
        final file = File(path);
        if (!await file.exists()) continue;

        // 获取视频元数据
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
        });
      }

      if (videoDataList.isNotEmpty && mounted) {
        context.read<LocalCompressBloc>().add(SelectVideos(videoDataList));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
