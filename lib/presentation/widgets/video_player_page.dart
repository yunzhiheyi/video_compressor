/// 全屏视频播放页面
///
/// 桌面端：使用 Chewie 提供完整控件（进度条、音量、倍速等）
/// 移动端：使用简单的 VideoPlayer（更轻量）
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/constants/app_colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoPath;
  final String? heroTag;
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
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));

    try {
      await _videoController!.initialize();
      if (!mounted) return;

      // 桌面端使用 Chewie
      if (Platform.isMacOS) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showOptions: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.white,
            handleColor: Colors.white,
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Video playback failed',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // 移动端直接播放
        _videoController!.play();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Video playback failed',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // 桌面端使用 Chewie
    if (Platform.isMacOS && _chewieController != null) {
      return Stack(
        children: [
          Center(
            child: widget.heroTag != null
                ? Hero(
                    tag: widget.heroTag!,
                    child: Material(
                      color: Colors.black,
                      child: Chewie(controller: _chewieController!),
                    ),
                  )
                : Chewie(controller: _chewieController!),
          ),
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

    // 移动端使用简单播放器
    return Stack(
      children: [
        Center(
          child: widget.heroTag != null
              ? Hero(
                  tag: widget.heroTag!,
                  child: Material(
                    color: Colors.black,
                    child: _buildSimpleVideoPlayer(),
                  ),
                )
              : _buildSimpleVideoPlayer(),
        ),
        GestureDetector(
          onTap: () {
            if (_videoController == null) return;
            setState(() {
              if (_videoController!.value.isPlaying) {
                _videoController!.pause();
              } else {
                _videoController!.play();
              }
            });
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: AnimatedOpacity(
                opacity: _videoController?.value.isPlaying ?? false ? 0.0 : 1.0,
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

  Widget _buildSimpleVideoPlayer() {
    if (_videoController == null) return const SizedBox();
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }
}
