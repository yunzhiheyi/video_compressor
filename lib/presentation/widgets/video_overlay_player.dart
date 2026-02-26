/// 视频Overlay播放器组件
///
/// 提供类似微信的视频预览交互体验：
/// - 点击缩略图后，视频从缩略图位置放大展开
/// - 支持手势拖动：向下拖动缩小并关闭
/// - 关闭时以手指触摸点为锚点缩放，实现流畅的跟随效果
/// - 支持点击播放/暂停
///
/// 使用方式：
/// ```dart
/// showVideoOverlay(
///   context: context,
///   videoPath: videoPath,
///   startRect: thumbnailRect,
///   thumbnail: thumbnailBytes,
/// );
/// ```
library;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频Overlay预览控制器
///
/// 用于控制Overlay的显示和隐藏，可在需要时手动关闭Overlay
class VideoOverlayController {
  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  /// 当前Overlay是否正在显示
  bool get isShowing => _isShowing;

  /// 关闭Overlay
  void dismiss() {
    if (_overlayEntry != null && _isShowing) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}

/// 显示视频Overlay预览
///
/// [context] - BuildContext，用于获取Overlay
/// [videoPath] - 视频文件路径
/// [startRect] - 起始位置和大小（通常是缩略图的位置）
/// [thumbnail] - 缩略图数据（可选，在视频加载时显示）
/// [controller] - 控制器（可选，用于外部控制关闭）
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

/// 视频Overlay视图（内部Widget）
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

/// 视频Overlay视图状态
///
/// 核心功能：
/// 1. 入场动画：从startRect放大到屏幕中央（保持宽高比不变）
/// 2. 手势拖动：支持拖动缩放和关闭
/// 3. 退出动画：Hero动画回到原位置或向下滑出
class _VideoOverlayViewState extends State<_VideoOverlayView>
    with TickerProviderStateMixin {
  // 动画控制器
  AnimationController? _scaleController; // 入场/退出缩放动画
  AnimationController? _fadeController; // 视频淡入动画
  AnimationController? _dragController; // 拖动关闭动画

  // 视频播放控制器
  VideoPlayerController? _videoController;
  bool _videoReady = false; // 视频是否初始化完成
  bool _isClosing = false; // 是否正在关闭
  bool _showVideo = false; // 是否显示视频（缩略图/视频切换）
  bool _initialized = false; // 是否已初始化

  // 位置和尺寸
  Rect _targetRect = Rect.zero; // 目标位置（屏幕中央，保持视频宽高比）
  Rect _sourceRect = Rect.zero; // 起始位置（保持与目标相同的宽高比）
  double _aspectRatio = 9.0 / 16.0; // 视频宽高比
  Size _screenSize = Size.zero; // 屏幕尺寸

  // 拖动状态
  double _dragOffsetX = 0.0; // X轴拖动偏移
  double _dragOffsetY = 0.0; // Y轴拖动偏移
  double _dragScale = 1.0; // 拖动时的缩放比例
  double _startOpacity = 1.0; // 开始关闭动画时的背景透明度
  double _closeAnimValue = 0.0; // 关闭动画进度值

  // 缩放锚点（手指触摸位置相对于窗口的比例）
  double _pivotX = 0.5; // 水平锚点（0=左边缘, 0.5=中心, 1=右边缘）
  double _pivotY = 0.0; // 垂直锚点（0=顶部, 0.5=中心, 1=底部）
  bool _pivotSet = false; // 锚点是否已设置

  // 关闭动画的起始和结束位置
  Rect? _closeStartRect;
  Rect? _closeEndRect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _screenSize = MediaQuery.of(context).size;
      _calculateRects(16.0 / 9.0);
      _initAnimations();
      _initVideo();
    }
  }

  /// 计算起始和目标位置（保持相同的宽高比）
  void _calculateRects(double aspectRatio) {
    _aspectRatio = aspectRatio;

    // 计算目标位置（屏幕中央，保持宽高比）
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

    // 计算起始位置：在原始缩略图区域内，保持与目标相同的宽高比
    final srcRect = widget.startRect;
    final srcCenter = srcRect.center;

    // 计算在原始区域内能容纳的最大尺寸（保持宽高比）
    double srcWidth, srcHeight;
    if (srcRect.width / srcRect.height > aspectRatio) {
      // 原始区域更宽，以高度为基准
      srcHeight = srcRect.height;
      srcWidth = srcHeight * aspectRatio;
    } else {
      // 原始区域更高，以宽度为基准
      srcWidth = srcRect.width;
      srcHeight = srcWidth / aspectRatio;
    }

    _sourceRect = Rect.fromCenter(
      center: srcCenter,
      width: srcWidth,
      height: srcHeight,
    );
  }

  /// 初始化动画控制器
  void _initAnimations() {
    // 缩放动画：控制入场/退出时的尺寸变化
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // 淡入动画：控制视频显示时的透明度
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // 拖动动画：控制拖动关闭时的动画
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // 入场动画完成后显示视频
    _scaleController!.forward().then((_) {
      if (_videoReady && mounted) {
        setState(() => _showVideo = true);
        _fadeController?.forward();
      }
    });
  }

  /// 初始化视频播放器
  void _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _videoController!.initialize();
      if (mounted && !_isClosing) {
        // 根据视频实际宽高比调整目标位置
        final videoAspect = _videoController!.value.aspectRatio;
        _calculateRects(videoAspect);

        setState(() {
          _videoReady = true;
        });

        // 如果入场动画已完成，显示视频
        if (_scaleController?.isCompleted == true) {
          setState(() => _showVideo = true);
          _fadeController?.forward();
        }

        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Video init failed: $e');
    }
  }

  /// 手势开始：记录手指触摸位置作为缩放锚点
  void _onPanStart(DragStartDetails details) {
    if (_isClosing) return;

    if (!_pivotSet) {
      _pivotSet = true;
      final baseRect = Rect.lerp(
        _sourceRect,
        _targetRect,
        _scaleController!.value,
      )!;
      final fingerGlobal = details.globalPosition;
      // 计算手指位置相对于窗口的比例（0-1）
      _pivotX = (fingerGlobal.dx - baseRect.left) / baseRect.width;
      _pivotY = (fingerGlobal.dy - baseRect.top) / baseRect.height;
    }
  }

  /// 手势更新：处理拖动
  ///
  /// 核心逻辑：
  /// 1. 累加拖动偏移量
  /// 2. 根据向下拖动距离计算缩放比例
  /// 3. 缩放以手指触摸点为锚点
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isClosing) return;

    _dragOffsetX += details.delta.dx;
    _dragOffsetY += details.delta.dy;

    // 向下拖动时缩小（最多缩小到50%）
    if (_dragOffsetY > 0) {
      _dragScale = 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 0.5);
    } else {
      _dragScale = 1.0;
    }

    setState(() {});
  }

  /// 手势结束：判断是关闭还是弹回
  void _onPanEnd(DragEndDetails details) {
    if (_isClosing) return;

    const threshold = 100.0; // 拖动距离阈值
    final velocity = details.velocity.pixelsPerSecond.dy;

    // 拖动超过阈值或速度足够快时关闭，否则弹回
    if (_dragOffsetY > threshold || velocity > 500) {
      _closeWithDrag();
    } else {
      _resetDrag();
    }
  }

  /// 拖动关闭：执行Hero动画回到原位置
  ///
  /// 动画过程：
  /// 1. 记录当前位置和大小
  /// 2. 从当前位置动画到起始位置（_sourceRect，保持宽高比）
  /// 3. 背景透明度从当前值渐变到0
  void _closeWithDrag() {
    if (_isClosing) return;
    _isClosing = true;

    _videoController?.pause();

    // 计算当前位置（考虑拖动偏移和缩放）
    final baseRect = Rect.lerp(
      _sourceRect,
      _targetRect,
      _scaleController!.value,
    )!;

    final currentWidth = baseRect.width * _dragScale;
    final currentHeight = baseRect.height * _dragScale;
    // 以手指触摸点为锚点计算位置
    final currentLeft = baseRect.left +
        (baseRect.width - currentWidth) * _pivotX +
        _dragOffsetX;
    final currentTop = baseRect.top +
        (baseRect.height - currentHeight) * _pivotY +
        _dragOffsetY;

    _closeStartRect =
        Rect.fromLTWH(currentLeft, currentTop, currentWidth, currentHeight);
    _closeEndRect = _sourceRect;

    // 记录当前背景透明度
    final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _startOpacity = 1.0 - dragProgress;

    // 创建关闭动画
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

  /// 重置拖动：弹回原位置
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
        _pivotSet = false; // 重置锚点标记
      }
    });

    _dragController!.forward();
  }

  /// 点击关闭按钮关闭
  void _close() async {
    if (_isClosing) return;
    _isClosing = true;

    _videoController?.pause();
    _fadeController?.reverse();

    if (mounted) {
      setState(() => _showVideo = false);
      await _scaleController?.reverse();
    }

    widget.onClose();
  }

  @override
  void dispose() {
    _scaleController?.dispose();
    _fadeController?.dispose();
    _dragController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _scaleController == null) {
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
              animation: Listenable.merge([_scaleController, _dragController]),
              builder: (context, child) {
                final scaleProgress = _scaleController!.value;
                var opacity = 1.0;

                // 计算背景透明度
                if (_isClosing &&
                    _closeStartRect != null &&
                    _dragController != null) {
                  // 拖动关闭时：从当前透明度渐变到0
                  opacity = _startOpacity * (1.0 - _closeAnimValue);
                } else if (_isClosing) {
                  // 点击关闭时：跟随缩放进度
                  opacity = scaleProgress;
                } else if (scaleProgress < 1.0) {
                  // 入场动画时：半透明
                  opacity = scaleProgress * 0.5;
                } else if (_dragOffsetY > 0) {
                  // 拖动时：根据拖动距离降低透明度
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
            animation: Listenable.merge([_scaleController, _dragController]),
            builder: (context, child) {
              Rect rect;

              if (_isClosing &&
                  _closeStartRect != null &&
                  _closeEndRect != null &&
                  _dragController != null) {
                // 关闭动画：从当前位置插值到起始位置
                rect = Rect.lerp(
                  _closeStartRect!,
                  _closeEndRect!,
                  _closeAnimValue,
                )!;
              } else {
                // 正常显示/拖动：计算当前位置（保持宽高比不变）
                final baseRect = Rect.lerp(
                  _sourceRect,
                  _targetRect,
                  _scaleController!.value,
                )!;

                final width = baseRect.width * _dragScale;
                final height = baseRect.height * _dragScale;
                // 以锚点为中心计算位置
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
              child: Builder(
                builder: (context) {
                  double borderRadius = 0.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 缩略图（视频加载时显示）
                          if (widget.thumbnail != null)
                            Image.memory(
                              widget.thumbnail!,
                              fit: BoxFit.cover,
                            ),
                          // 视频播放器
                          if (_videoReady &&
                              _showVideo &&
                              _fadeController != null)
                            FadeTransition(
                              opacity: _fadeController!,
                              child: VideoPlayer(_videoController!),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
                    if (_dragOffsetY > 10) return; // 拖动时不响应点击
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
                                // 播放时隐藏按钮，拖动时也隐藏
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
            animation: Listenable.merge([_scaleController, _dragController]),
            builder: (context, child) {
              // 入场动画未完成或正在关闭时隐藏
              if (_scaleController!.value < 0.5 || _isClosing) {
                return const SizedBox.shrink();
              }
              // 拖动时渐隐
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
///
/// [key] - Widget的GlobalKey
/// 返回Widget相对于屏幕的Rect
Rect getWidgetGlobalRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderObject == null) return Rect.zero;

  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}
