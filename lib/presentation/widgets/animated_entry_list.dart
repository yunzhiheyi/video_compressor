/// 列表项入场动画组件
///
/// 实现类似 iOS 列表的入场动画效果：
/// - 从右侧（或底部）滑入
/// - 带有弹性回弹效果（bounce）
/// - 支持交错延迟，多个item依次动画
///
/// 特点：
/// - 只对新添加的item播放动画
/// - 已动画过的item不会重复播放
/// - 支持标记/取消标记动画状态（用于删除后重新添加）
///
/// 使用方式：
/// ```dart
/// AnimatedEntryItem(
///   itemKey: item.id,
///   index: index,
///   hasAnimated: (key) => animatedKeys.contains(key),
///   markAsAnimated: (key) => animatedKeys.add(key),
///   child: ListItem(),
/// )
/// ```
import 'package:flutter/material.dart';

/// 动画方向枚举
enum AnimationDirection {
  vertical, // 从底部向上滑入
  horizontal, // 从右侧向左滑入
  both, // 同时从右下向左上滑入
}

/// 列表项入场动画Widget
class AnimatedEntryItem extends StatefulWidget {
  /// 唯一标识符，用于判断是否已动画过
  final String itemKey;

  /// 列表索引，用于计算交错延迟
  final int index;

  /// 子Widget
  final Widget child;

  /// 动画时长（毫秒）
  final int duration;

  /// 弹性回弹深度（像素）
  final double reBounceDepth;

  /// 动画方向
  final AnimationDirection animationDirection;

  /// 透明度变化范围
  final Tween<double>? opacityRange;

  /// 检查是否已动画过的回调
  final bool Function(String key)? hasAnimated;

  /// 标记为已动画的回调
  final void Function(String key)? markAsAnimated;

  const AnimatedEntryItem({
    super.key,
    required this.itemKey,
    required this.index,
    required this.child,
    this.duration = 800,
    this.reBounceDepth = 10,
    this.animationDirection = AnimationDirection.horizontal,
    this.opacityRange,
    this.hasAnimated,
    this.markAsAnimated,
  });

  @override
  State<AnimatedEntryItem> createState() => AnimatedEntryItemState();
}

/// 列表项入场动画状态
class AnimatedEntryItemState extends State<AnimatedEntryItem>
    with SingleTickerProviderStateMixin {
  /// 批次计数器，用于同一批次添加的item交错动画
  static int _batchCounter = 0;

  /// 上次批次时间，超过500ms则重置计数器
  static DateTime? _lastBatchTime;

  late AnimationController _controller;

  /// 位置动画：从初始位置滑动到0
  late Animation<double> _positionAnimation;

  /// 向前弹跳动画：0 → reBounceDepth
  late Animation<double> _bounceForwardAnimation;

  /// 返回弹跳动画：0 → reBounceDepth
  /// 最终偏移 = position + bounceForward - bounceReturn
  late Animation<double> _bounceReturnAnimation;

  /// 透明度动画
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );

    _setupAnimations();

    // 检查是否已动画过
    final hasAnimated = widget.hasAnimated?.call(widget.itemKey) ?? false;
    if (hasAnimated) {
      // 已动画过，直接显示完成状态
      _controller.value = 1.0;
    } else {
      // 新item，计算交错延迟
      final now = DateTime.now();
      if (_lastBatchTime == null ||
          now.difference(_lastBatchTime!).inMilliseconds > 500) {
        // 超过500ms，认为是新批次，重置计数器
        _batchCounter = 0;
        _lastBatchTime = now;
      }

      // 交错延迟：每5个一组，每组内依次延迟80ms
      final delay = (_batchCounter % 5) * 80;
      _batchCounter++;

      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          _controller.forward();
          widget.markAsAnimated?.call(widget.itemKey);
        }
      });
    }
  }

  /// 设置动画曲线
  ///
  /// 动画分为三个阶段：
  /// 1. 位置动画（0-50%）：从初始位置滑到0
  /// 2. 向前弹跳（50-70%）：向外弹出一小段距离
  /// 3. 返回弹跳（70-100%）：弹回到0
  void _setupAnimations() {
    // 位置动画：从250px（水平）或300px（垂直）滑到0
    _positionAnimation = Tween<double>(
      begin: widget.animationDirection == AnimationDirection.vertical
          ? 300.0
          : 250.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 向前弹跳：从0弹到reBounceDepth
    _bounceForwardAnimation = Tween<double>(
      begin: 0.0,
      end: widget.reBounceDepth,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.7, curve: Curves.easeOut),
      ),
    );

    // 返回弹跳：从0弹到reBounceDepth（与前向相减实现弹性效果）
    _bounceReturnAnimation = Tween<double>(
      begin: 0.0,
      end: widget.reBounceDepth,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    // 透明度动画：从0渐变到1
    _opacityAnimation =
        (widget.opacityRange ?? Tween<double>(begin: 0.0, end: 1.0)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 计算垂直偏移
        final verticalOffset =
            widget.animationDirection == AnimationDirection.vertical ||
                    widget.animationDirection == AnimationDirection.both
                ? _positionAnimation.value +
                    _bounceForwardAnimation.value -
                    _bounceReturnAnimation.value
                : 0.0;

        // 计算水平偏移
        final horizontalOffset =
            widget.animationDirection == AnimationDirection.horizontal ||
                    widget.animationDirection == AnimationDirection.both
                ? _positionAnimation.value +
                    _bounceForwardAnimation.value -
                    _bounceReturnAnimation.value
                : 0.0;

        return Transform.translate(
          offset: Offset(horizontalOffset, verticalOffset),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
