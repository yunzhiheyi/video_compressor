import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context, {
    Color? indicatorColor,
    double indicatorWidth = 3.0,
    String? message,
    Color? backgroundColor,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingWidget(
        indicatorColor: indicatorColor,
        indicatorWidth: indicatorWidth,
        message: message,
        backgroundColor: backgroundColor,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static bool get isShowing => _overlayEntry != null;
}

class _LoadingWidget extends StatelessWidget {
  final Color? indicatorColor;
  final double indicatorWidth;
  final String? message;
  final Color? backgroundColor;

  const _LoadingWidget({
    this.indicatorColor,
    this.indicatorWidth = 3.0,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: backgroundColor ?? const Color(0xCC000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: indicatorWidth,
                valueColor: AlwaysStoppedAnimation<Color>(
                  indicatorColor ?? AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
