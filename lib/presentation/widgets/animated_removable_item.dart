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
    this.shrinkDuration = const Duration(milliseconds: 150),
  });

  @override
  State<AnimatedRemovableItem> createState() => AnimatedRemovableItemState();
}

class AnimatedRemovableItemState extends State<AnimatedRemovableItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.slideDuration,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void remove() {
    if (_isRemoving) return;
    setState(() => _isRemoving = true);
    _controller.forward().then((_) {
      widget.onRemove();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRemoving) {
      return widget.child;
    }

    return AnimatedSize(
      duration: widget.shrinkDuration,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
