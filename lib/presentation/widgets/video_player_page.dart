/// 全屏视频播放页面
///
/// 提供全屏视频播放功能，支持：
/// - 自适应视频宽高比
/// - 点击播放/暂停
/// - 播放控制按钮自动隐藏
/// - Hero动画过渡（可选）
///
/// 使用 video_player 包进行视频播放。
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 全屏视频播放页面组件
///
/// 显示一个全屏的视频播放器，带有播放控制和关闭按钮。
/// 支持Hero动画过渡效果。
class VideoPlayerPage extends StatefulWidget {
  /// 视频文件的本地路径
  final String videoPath;

  /// Hero动画标签，用于页面过渡动画
  final String? heroTag;

  /// 视频缩略图数据，在视频加载时显示
  final Uint8List? thumbnail;

  const VideoPlayerPage({
    super.key,
    required this.videoPath,
    this.heroTag,
    this.thumbnail,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  /// 视频播放控制器
  VideoPlayerController? _controller;

  /// 是否发生播放错误
  bool _hasError = false;

  /// 视频是否已初始化完成
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  /// 初始化视频播放器
  ///
  /// 创建控制器并尝试加载视频文件，
  /// 初始化成功后自动开始播放。
  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _controller!.addListener(_videoListener);
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  /// 视频状态变化监听器
  ///
  /// 当视频播放状态变化时触发UI刷新。
  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  /// 构建页面主体内容
  ///
  /// 根据视频加载状态显示不同的内容：
  /// - 加载错误：显示错误提示
  /// - 正在加载：显示加载指示器
  /// - 加载完成：显示视频播放器
  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Video playback failed',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      children: [
        // 视频播放器，使用Hero动画过渡
        Center(
          child: widget.heroTag != null
              ? Hero(
                  tag: widget.heroTag!,
                  child: Material(
                    color: Colors.black,
                    child: _buildVideoContent(),
                  ),
                )
              : _buildVideoContent(),
        ),
        // 播放/暂停控制层
        GestureDetector(
          onTap: () {
            if (_controller == null) return;
            setState(() {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            });
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: AnimatedOpacity(
                opacity: _controller?.value.isPlaying ?? false ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
        // 关闭按钮 - 最上层
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建视频内容组件
  ///
  /// 使用AspectRatio确保视频按正确比例显示。
  Widget _buildVideoContent() {
    if (_controller == null) return const SizedBox();
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
