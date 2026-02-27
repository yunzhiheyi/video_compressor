import 'package:flutter/material.dart';

class AnimatedRemovableItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onRemove;
  final Duration slideDuration;
  final Duration shrinkDuration;

  const AnimatedRemovableItem({
    super.key,
    required this.child,
    required this.onRemove,
    this.slideDuration = const Duration(milliseconds: 200),
    this.shrinkDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedRemovableItem> createState() => AnimatedRemovableItemState();
}

class AnimatedRemovableItemState extends State<AnimatedRemovableItem>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shrinkController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heightAnimation;
  bool _isRemoving = false;
  double? _originalHeight;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: widget.slideDuration,
      vsync: this,
    );
    _shrinkController = AnimationController(
      duration: widget.shrinkDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _heightAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _shrinkController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shrinkController.dispose();
    super.dispose();
  }

  void remove() {
    if (_isRemoving) return;
    setState(() => _isRemoving = true);

    // 先播放滑出动画
    _slideController.forward().then((_) {
      // 滑出完成后播放收缩动画
      _shrinkController.forward().then((_) {
        widget.onRemove();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRemoving) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _shrinkController,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _heightAnimation.value,
            child: child,
          ),
        );
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
