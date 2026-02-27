/// 视频选择器页面
///
/// 提供跨平台的视频选择功能：
/// - macOS：使用文件选择器选择视频文件
/// - iOS/Android：使用相册选择器，支持多选和预览
///
/// 主要功能：
/// - 从相册加载视频列表
/// - 显示视频缩略图和时长
/// - 支持多选视频（可配置最大数量）
/// - 支持视频预览（使用WeChat风格的overlay播放器）
/// - 自动缓存缩略图和视频路径
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../services/ffmpeg_service.dart';
import 'video_overlay_player.dart';

/// 视频选择器页面组件
///
/// 根据平台自动适配UI：
/// - macOS：显示桌面风格的文件选择界面
/// - iOS/Android：显示相册网格界面
class VideoPickerPage extends StatefulWidget {
  /// 最大可选视频数量
  final int maxCount;

  /// FFmpeg服务（用于获取帧率、码率信息）
  final FFmpegService? ffmpegService;

  const VideoPickerPage({
    super.key,
    this.maxCount = 10,
    this.ffmpegService,
  });

  /// 检查相册访问权限
  ///
  /// macOS平台默认有权限，返回true。
  /// iOS/Android平台需要请求相册权限。
  ///
  /// 返回是否有访问权限。
  static Future<bool> checkPermission() async {
    if (Platform.isMacOS) return true;
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.isLimited;
  }

  @override
  State<VideoPickerPage> createState() => _VideoPickerPageState();
}

class _VideoPickerPageState extends State<VideoPickerPage> {
  /// 相册列表
  List<AssetPathEntity> _albums = [];

  /// 当前选中的相册
  AssetPathEntity? _selectedAlbum;

  /// 当前相册中的视频列表
  List<AssetEntity> _videos = [];

  /// 用户选中的视频集合
  final Set<AssetEntity> _selectedVideos = {};

  /// 视频缩略图缓存（key: videoId, value: thumbnail bytes）
  final Map<String, dynamic> _thumbnailCache = {};

  /// 加载失败的缩略图ID集合，避免重复尝试
  final Set<String> _failedThumbnails = {};

  /// 视频文件路径缓存（key: videoId, value: file path）
  final Map<String, String> _videoPathCache = {};

  /// 视频项的GlobalKey，用于获取位置实现Hero动画
  final Map<String, GlobalKey> _itemKeys = {};

  /// 视频overlay播放器控制器
  final VideoOverlayController _overlayController = VideoOverlayController();

  /// 相册列表滚动控制器
  final ScrollController _albumScrollController = ScrollController();

  /// 是否正在加载
  bool _isLoading = true;

  /// 已加载缩略图的视频ID集合
  final Set<String> _loadedThumbnails = {};

  /// 是否为受限权限（iOS Limited Photos Library）
  bool _isLimitedPermission = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS) {
      _isLoading = false;
    } else {
      _loadAlbums();
    }
  }

  @override
  void dispose() {
    _albumScrollController.dispose();
    super.dispose();
  }

  /// 加载相册列表
  ///
  /// 请求相册权限并获取所有包含视频的相册。
  Future<void> _loadAlbums() async {
    if (Platform.isMacOS) return;
    setState(() => _isLoading = true);

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!ps.isAuth && !ps.isLimited) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please grant photo library access')),
        );
      }
      return;
    }

    _isLimitedPermission = ps.isLimited;

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: false,
    );

    if (!mounted) return;

    if (albums.isNotEmpty) {
      _albums = albums;
      _selectedAlbum = albums.first;
      // 先加载视频列表
      await _loadVideos();
      // 预加载第一批缩略图（屏幕可见的数量）
      await _preloadThumbnails();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// 加载当前相册中的视频列表
  Future<void> _loadVideos() async {
    if (Platform.isMacOS || _selectedAlbum == null) return;

    try {
      final List<AssetEntity> videos = await _selectedAlbum!.getAssetListRange(
        start: 0,
        end: 1000,
      );
      if (!mounted) return;
      setState(() => _videos = videos);
    } catch (e) {
      debugPrint('Video list load failed: $e');
      if (mounted) setState(() => _videos = []);
    }
  }

  /// 预加载第一批缩略图
  Future<void> _preloadThumbnails() async {
    if (_videos.isEmpty) return;

    // 预加载前18个（3列x6行）
    final preloadCount = _videos.length < 18 ? _videos.length : 18;
    final futures = <Future>[];

    for (int i = 0; i < preloadCount; i++) {
      final video = _videos[i];
      if (_thumbnailCache.containsKey(video.id)) continue;

      futures.add(_loadSingleThumbnail(video));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// 加载单个缩略图
  Future<void> _loadSingleThumbnail(AssetEntity video) async {
    try {
      final thumbnail =
          await video.thumbnailDataWithSize(const ThumbnailSize(200, 200));
      final file = await video.file;

      if (file != null) {
        _videoPathCache[video.id] = file.path;
      }

      if (thumbnail != null && mounted) {
        _thumbnailCache[video.id] = thumbnail;
        _loadedThumbnails.add(video.id);
      }
    } catch (e) {
      _failedThumbnails.add(video.id);
    }
  }

  /// 切换视频的选中状态
  void _toggleSelection(AssetEntity video) {
    setState(() {
      if (_selectedVideos.contains(video)) {
        _selectedVideos.remove(video);
      } else if (_selectedVideos.length < widget.maxCount) {
        _selectedVideos.add(video);
      }
    });
  }

  /// 确认选择并返回结果
  ///
  /// macOS平台打开文件选择器。
  /// 移动平台返回选中的视频数据（路径、缩略图、宽高、时长、大小、帧率、码率）。
  Future<void> _confirmSelection() async {
    if (Platform.isMacOS) {
      await _pickFilesOnMacOS();
      return;
    }

    LoadingOverlay.show(context);

    final List<Map<String, dynamic>> videoData = [];
    for (final video in _selectedVideos) {
      final file = await video.file;
      if (file != null) {
        final fileSize = await file.length();

        // 获取帧率和码率信息
        int? bitrate;
        double? frameRate;
        if (widget.ffmpegService != null) {
          try {
            final info = await widget.ffmpegService!.getVideoInfo(file.path);
            bitrate = info['bitrate'] as int?;
            frameRate = info['frameRate'] as double?;
          } catch (e) {
            debugPrint('[VideoPicker] Failed to get video info: $e');
          }
        }

        videoData.add({
          'path': file.path,
          'name': file.path.split('/').last,
          'thumbnailBytes': _thumbnailCache[video.id],
          'width': video.width,
          'height': video.height,
          'duration': video.duration.toDouble(),
          'size': fileSize,
          'bitrate': bitrate,
          'frameRate': frameRate,
        });
      }
    }

    LoadingOverlay.hide();
    if (mounted) Navigator.pop(context, videoData);
  }

  /// macOS平台的文件选择
  ///
  /// 使用FilePicker打开视频文件选择对话框。
  Future<void> _pickFilesOnMacOS() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final paths = result.paths.whereType<String>().toList();
        Navigator.pop(context, paths);
      }
    } catch (e) {
      debugPrint('File selection failed: $e');
    }
  }

  /// 格式化视频时长为可读字符串
  ///
  /// [seconds] - 视频秒数
  /// 返回格式如 "01:30:45" 或 "05:30"
  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 预览视频
  ///
  /// 使用WeChat风格的overlay播放器预览视频。
  /// 支持Hero动画从缩略图位置展开。
  void _previewVideo(AssetEntity video) {
    final cachedPath = _videoPathCache[video.id];
    final thumbnail = _thumbnailCache[video.id];
    final itemKey = _itemKeys[video.id];

    // 获取视频宽高比（考虑旋转方向）
    final aspectRatio = video.orientatedWidth / video.orientatedHeight;

    if (cachedPath != null && itemKey != null) {
      showVideoOverlay(
        context: context,
        videoPath: cachedPath,
        startRect: getWidgetGlobalRect(itemKey),
        thumbnail: thumbnail,
        aspectRatio: aspectRatio,
        controller: _overlayController,
      );
    } else {
      _previewVideoAsync(video);
    }
  }

  /// 异步预览视频
  ///
  /// 当视频路径未缓存时，先加载路径再预览。
  void _previewVideoAsync(AssetEntity video) async {
    final file = await video.file;
    if (file != null && mounted) {
      _videoPathCache[video.id] = file.path;
      final itemKey = _itemKeys[video.id];
      // 获取视频宽高比（考虑旋转方向）
      final aspectRatio = video.orientatedWidth / video.orientatedHeight;
      showVideoOverlay(
        context: context,
        videoPath: file.path,
        startRect: itemKey != null ? getWidgetGlobalRect(itemKey) : Rect.zero,
        thumbnail: _thumbnailCache[video.id],
        aspectRatio: aspectRatio,
        controller: _overlayController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) return _buildMacOSDesktopUI();
    return _buildMobileUI();
  }

  /// 构建macOS桌面端UI
  ///
  /// 显示简洁的文件选择界面，支持拖放提示。
  Widget _buildMacOSDesktopUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          _buildDesktopTitleBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_library_outlined,
                        size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 32),
                  const Text('Select Video Files',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                      'Supports MP4, MOV, AVI, etc. Max ${widget.maxCount} files',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _pickFilesOnMacOS,
                    icon: const Icon(Icons.folder_open, size: 22),
                    label: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Browse Files',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_indicator,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 20),
                        const SizedBox(width: 8),
                        Text('Or drag and drop video files here',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDesktopBottomBar(),
        ],
      ),
    );
  }

  /// 构建桌面端标题栏
  Widget _buildDesktopTitleBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
              child: Text('Video Compressor - Select Videos',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  /// 构建桌面端底部状态栏
  Widget _buildDesktopBottomBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Text('Video Compressor v1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          const Spacer(),
          Text('Supported: MP4, MOV, AVI, MKV',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  /// 构建移动端UI
  Widget _buildMobileUI() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(
              Icons.close,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context)),
        title: _buildAlbumDropdown(),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        actions: [
          if (_selectedVideos.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text('Done(${_selectedVideos.length})',
                  style: const TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: _isLoading ? _buildSkeletonGrid() : _buildMobileBody(),
    );
  }

  /// 构建骨架屏网格
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 18,
      itemBuilder: (context, index) => Container(
        color: AppColors.surface,
        child: const SizedBox.expand(),
      ),
    );
  }

  /// 构建相册下拉选择器
  Widget _buildAlbumDropdown() {
    return GestureDetector(
      onTap: _albums.isNotEmpty ? () => _showAlbumSheet() : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _selectedAlbum?.name ?? 'Select Album',
              style: TextStyle(
                  color: _albums.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_albums.isNotEmpty) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary, size: 20),
          ],
        ],
      ),
    );
  }

  /// 显示相册选择底部表单
  void _showAlbumSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Album',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _albumScrollController,
                itemCount: _albums.length,
                itemBuilder: (context, index) {
                  final album = _albums[index];
                  final isSelected = album.id == _selectedAlbum?.id;
                  return ListTile(
                    leading: const Icon(Icons.folder,
                        color: AppColors.textSecondary),
                    title: Text(album.name),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                    onTap: () {
                      _switchAlbum(album);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换相册
  ///
  /// 清除当前缓存并加载新相册的视频列表。
  void _switchAlbum(AssetPathEntity album) async {
    setState(() {
      _selectedAlbum = album;
      _thumbnailCache.clear();
      _videoPathCache.clear();
      _itemKeys.clear();
      _selectedVideos.clear();
      _failedThumbnails.clear();
      _loadedThumbnails.clear();
      _isLoading = true;
    });

    await _loadVideos();
    await _preloadThumbnails();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 构建移动端主体内容
  Widget _buildMobileBody() {
    return Column(
      children: [
        // 受限权限提示
        if (_isLimitedPermission)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.withValues(alpha: 0.2),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Limited access. Tap to change permissions.',
                        style: TextStyle(
                            color: Colors.orange[700], fontSize: 12))),
                TextButton(
                  onPressed: () async => await PhotoManager.openSetting(),
                  child: Text('Settings',
                      style:
                          TextStyle(color: Colors.orange[700], fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined,
                          size: 64,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No videos found',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) =>
                      _buildVideoItem(_videos[index]),
                ),
        ),
      ],
    );
  }

  /// 构建单个视频项
  ///
  /// 显示缩略图、时长、选中状态和播放按钮。
  Widget _buildVideoItem(AssetEntity video) {
    final isSelected = _selectedVideos.contains(video);

    _itemKeys.putIfAbsent(video.id, () => GlobalKey());

    return GestureDetector(
      onTap: () => _toggleSelection(video),
      child: Container(
        key: _itemKeys[video.id],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图
            _VideoThumbnailWidget(
              videoId: video.id,
              cache: _thumbnailCache,
              failedSet: _failedThumbnails,
              onPathLoaded: (path) {
                _videoPathCache[video.id] = path;
              },
              onThumbnailLoaded: () {
                if (!_loadedThumbnails.contains(video.id)) {
                  setState(() {
                    _loadedThumbnails.add(video.id);
                  });
                }
              },
            ),
            // 选中遮罩
            if (isSelected)
              Container(color: AppColors.primary.withValues(alpha: 0.3)),
            // 底部时长
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
                child: Text(_formatDuration(video.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            // 右上角选择按钮
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleSelection(video),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(
                    child: isSelected
                        ? Text('${_selectedVideos.toList().indexOf(video) + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600))
                        : null,
                  ),
                ),
              ),
            ),
            // 播放按钮（最上层，只有缩略图加载完成后才显示）
            if (_loadedThumbnails.contains(video.id))
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _previewVideo(video),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 独立的缩略图Widget
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> cache;
  final Set<String> failedSet;
  final Function(String path)? onPathLoaded;
  final VoidCallback? onThumbnailLoaded;

  const _VideoThumbnailWidget({
    required this.videoId,
    required this.cache,
    required this.failedSet,
    this.onPathLoaded,
    this.onThumbnailLoaded,
  });

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _thumbnail;
  bool _isLoading = true;
  bool _loadStarted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(_VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _loadStarted = false;
      _checkCacheAndLoad();
    }
  }

  void _checkCacheAndLoad() {
    if (_loadStarted) return;

    if (widget.cache.containsKey(widget.videoId)) {
      _thumbnail = widget.cache[widget.videoId] as Uint8List?;
      _isLoading = false;
      _loadStarted = true;
      return;
    }

    if (widget.failedSet.contains(widget.videoId)) {
      _isLoading = false;
      _loadStarted = true;
      return;
    }

    _loadStarted = true;
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final entity = await AssetEntity.fromId(widget.videoId);
      if (entity == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final results = await Future.wait([
        entity.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
        entity.file,
      ]);

      final thumbnail = results[0] as Uint8List?;
      final file = results[1] as File?;

      if (file != null && widget.onPathLoaded != null) {
        widget.onPathLoaded!(file.path);
      }

      if (!mounted) return;

      if (thumbnail != null) {
        widget.cache[widget.videoId] = thumbnail;
        if (widget.onThumbnailLoaded != null) {
          widget.onThumbnailLoaded!();
        }
        setState(() {
          _thumbnail = thumbnail;
          _isLoading = false;
        });
      } else {
        widget.failedSet.add(widget.videoId);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        widget.failedSet.add(widget.videoId);
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Thumbnail load failed for video ${widget.videoId}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_thumbnail != null) {
      return Image.memory(_thumbnail!, fit: BoxFit.cover);
    }

    return Container(color: AppColors.surface);
  }
}
