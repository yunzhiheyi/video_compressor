library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频Overlay预览控制器
class VideoOverlayController {
  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  bool get isShowing => _isShowing;

  void dismiss() {
    if (_overlayEntry != null && _isShowing) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}

/// 显示视频Overlay预览
void showVideoOverlay({
  required BuildContext context,
  required String videoPath,
  required Rect startRect,
  Uint8List? thumbnail,
  VideoOverlayController? controller,
}) {
  final overlayController = controller ?? VideoOverlayController();

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _VideoOverlayView(
      videoPath: videoPath,
      startRect: startRect,
      thumbnail: thumbnail,
      onClose: () {
        overlayEntry.remove();
        overlayController._overlayEntry = null;
        overlayController._isShowing = false;
      },
    ),
  );

  overlayController._overlayEntry = overlayEntry;
  overlayController._isShowing = true;
  Overlay.of(context).insert(overlayEntry);
}

class _VideoOverlayView extends StatefulWidget {
  final String videoPath;
  final Rect startRect;
  final Uint8List? thumbnail;
  final VoidCallback onClose;

  const _VideoOverlayView({
    required this.videoPath,
    required this.startRect,
    this.thumbnail,
    required this.onClose,
  });

  @override
  State<_VideoOverlayView> createState() => _VideoOverlayViewState();
}

class _VideoOverlayViewState extends State<_VideoOverlayView>
    with TickerProviderStateMixin {
  AnimationController? _expandController;
  AnimationController? _fadeController;
  AnimationController? _dragController;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isClosing = false;
  bool _showVideo = false;
  bool _initialized = false;

  late Rect _startRect;
  late Rect _targetRect;
  late Size _screenSize;
  double _aspectRatio = 9.0 / 16.0;

  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;
  double _dragScale = 1.0;
  double _startOpacity = 1.0;
  double _closeAnimValue = 0.0;

  double _pivotX = 0.5;
  double _pivotY = 0.5;
  bool _pivotSet = false;

  Rect? _closeStartRect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _screenSize = MediaQuery.of(context).size;
      _startRect = widget.startRect;
      _calculateTargetRect(_aspectRatio);
      _initAnimations();
      _initVideo();
    }
  }

  void _calculateTargetRect(double aspectRatio) {
    _aspectRatio = aspectRatio;

    double targetWidth = _screenSize.width;
    double targetHeight = targetWidth / aspectRatio;

    if (targetHeight > _screenSize.height) {
      targetHeight = _screenSize.height;
      targetWidth = targetHeight * aspectRatio;
    }

    _targetRect = Rect.fromCenter(
      center: Offset(_screenSize.width / 2, _screenSize.height / 2),
      width: targetWidth,
      height: targetHeight,
    );
  }

  void _initAnimations() {
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _dragController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _expandController!.forward().then((_) {
      if (_videoReady && mounted) {
        setState(() => _showVideo = true);
        _fadeController?.forward();
      }
    });
  }

  void _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _videoController!.initialize();
      if (mounted && !_isClosing) {
        // 根据视频实际宽高比更新目标rect
        final videoAspect = _videoController!.value.aspectRatio;
        _calculateTargetRect(videoAspect);

        setState(() {
          _videoReady = true;
        });

        if (_expandController?.isCompleted == true) {
          setState(() => _showVideo = true);
          _fadeController?.forward();
        }

        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Video init failed: $e');
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isClosing) return;

    if (!_pivotSet) {
      _pivotSet = true;
      final currentRect = _getCurrentRect();
      final fingerGlobal = details.globalPosition;
      _pivotX = (fingerGlobal.dx - currentRect.left) / currentRect.width;
      _pivotY = (fingerGlobal.dy - currentRect.top) / currentRect.height;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isClosing) return;

    _dragOffsetX += details.delta.dx;
    _dragOffsetY += details.delta.dy;

    if (_dragOffsetY > 0) {
      _dragScale = 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 0.5);
    } else {
      _dragScale = 1.0;
    }

    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isClosing) return;

    const threshold = 100.0;
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (_dragOffsetY > threshold || velocity > 500) {
      _closeWithDrag();
    } else {
      _resetDrag();
    }
  }

  Rect _getCurrentRect() {
    final t = _expandController?.value ?? 0.0;
    return Rect.lerp(_startRect, _targetRect, t)!;
  }

  void _closeWithDrag() {
    if (_isClosing) return;
    _isClosing = true;

    _videoController?.pause();

    final currentRect = _getCurrentRect();
    final currentWidth = currentRect.width * _dragScale;
    final currentHeight = currentRect.height * _dragScale;
    final currentLeft = currentRect.left +
        (currentRect.width - currentWidth) * _pivotX +
        _dragOffsetX;
    final currentTop = currentRect.top +
        (currentRect.height - currentHeight) * _pivotY +
        _dragOffsetY;

    _closeStartRect =
        Rect.fromLTWH(currentLeft, currentTop, currentWidth, currentHeight);

    final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _startOpacity = 1.0 - dragProgress;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final curve = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    curve.addListener(() {
      setState(() {
        _closeAnimValue = curve.value;
      });
    });

    curve.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onClose();
      }
    });

    _dragController!.forward();
  }

  void _resetDrag() {
    final startOffsetX = _dragOffsetX;
    final startOffsetY = _dragOffsetY;
    final startScale = _dragScale;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    animation.addListener(() {
      setState(() {
        _dragOffsetX = startOffsetX * (1 - animation.value);
        _dragOffsetY = startOffsetY * (1 - animation.value);
        _dragScale = 1.0 - (1.0 - startScale) * (1 - animation.value);
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _pivotSet = false;
      }
    });

    _dragController!.forward();
  }

  void _close() async {
    if (_isClosing) return;
    _isClosing = true;

    _videoController?.pause();
    _fadeController?.reverse();

    if (mounted) {
      setState(() => _showVideo = false);
      await _expandController?.reverse();
    }

    widget.onClose();
  }

  @override
  void dispose() {
    _expandController?.dispose();
    _fadeController?.dispose();
    _dragController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _expandController == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 背景遮罩层
          GestureDetector(
            onTap: !_isClosing && _dragOffsetY < 10 ? _close : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_expandController, _dragController]),
              builder: (context, child) {
                final t = _expandController!.value;
                var opacity = 1.0;

                if (_isClosing && _closeStartRect != null) {
                  opacity = _startOpacity * (1.0 - _closeAnimValue);
                } else if (_isClosing) {
                  opacity = t;
                } else if (t < 1.0) {
                  opacity = t;
                } else if (_dragOffsetY > 0) {
                  final dragProgress =
                      (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
                  opacity = 1.0 - dragProgress;
                }

                return Container(
                  color: Colors.black.withValues(alpha: opacity),
                  width: double.infinity,
                  height: double.infinity,
                );
              },
            ),
          ),
          // 视频内容层
          AnimatedBuilder(
            animation: Listenable.merge([_expandController, _dragController]),
            builder: (context, child) {
              Rect rect;

              if (_isClosing && _closeStartRect != null) {
                rect = Rect.lerp(
                  _closeStartRect!,
                  _startRect,
                  _closeAnimValue,
                )!;
              } else {
                final t = _expandController!.value;
                final baseRect = Rect.lerp(_startRect, _targetRect, t)!;

                final width = baseRect.width * _dragScale;
                final height = baseRect.height * _dragScale;
                final left = baseRect.left +
                    (baseRect.width - width) * _pivotX +
                    _dragOffsetX;
                final top = baseRect.top +
                    (baseRect.height - height) * _pivotY +
                    _dragOffsetY;

                rect = Rect.fromLTWH(left, top, width, height);
              }

              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: child!,
              );
            },
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 缩略图
                      if (widget.thumbnail != null)
                        Image.memory(
                          widget.thumbnail!,
                          fit: BoxFit.cover,
                        ),
                      // 视频播放器
                      if (_videoReady && _showVideo && _fadeController != null)
                        FadeTransition(
                          opacity: _fadeController!,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 播放/暂停控制层
          if (_showVideo)
            Positioned.fill(
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onTap: () {
                    if (_videoController == null) return;
                    if (_dragOffsetY > 10) return;
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
                    child: Center(
                      child: _videoController != null
                          ? AnimatedBuilder(
                              animation: _videoController!,
                              builder: (context, child) {
                                final isPlaying =
                                    _videoController!.value.isPlaying;
                                final opacity =
                                    isPlaying || _dragOffsetY > 10 ? 0.0 : 1.0;
                                return AnimatedOpacity(
                                  opacity: opacity,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          // 关闭按钮
          AnimatedBuilder(
            animation: Listenable.merge([_expandController, _dragController]),
            builder: (context, child) {
              if (_expandController!.value < 0.5 || _isClosing) {
                return const SizedBox.shrink();
              }
              final opacity = 1.0 - (_dragOffsetY / 100).clamp(0.0, 1.0);
              return Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 获取Widget在屏幕上的位置和大小
Rect getWidgetGlobalRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderObject == null) return Rect.zero;

  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}
