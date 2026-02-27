import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../pages/history/history_state.dart';
import '../widgets/video_player_page.dart';
import '../../utils/app_toast.dart';
import 'package:gal/gal.dart';
import 'history_item_card.dart';

enum HistoryDetailStyle { bottomSheet, dialog }

class HistoryDetailContent extends StatelessWidget {
  final HistoryItem item;
  final HistoryDetailStyle style;
  final VoidCallback? onClose;
  final bool showSaveToGallery;

  const HistoryDetailContent({
    super.key,
    required this.item,
    this.style = HistoryDetailStyle.bottomSheet,
    this.onClose,
    this.showSaveToGallery = true,
  });

  static Future<void> show(
    BuildContext context, {
    required HistoryItem item,
    HistoryDetailStyle style = HistoryDetailStyle.bottomSheet,
    bool showSaveToGallery = true,
  }) {
    if (style == HistoryDetailStyle.bottomSheet) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: HistoryDetailContent(
              item: item,
              style: style,
              showSaveToGallery: showSaveToGallery,
            ),
          ),
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          content: SizedBox(
            width: 400,
            child: HistoryDetailContent(
              item: item,
              style: style,
              showSaveToGallery: showSaveToGallery,
              onClose: () => Navigator.pop(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name,
            style: TextStyle(
                color: style == HistoryDetailStyle.dialog
                    ? Colors.white
                    : AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _buildSizeInfo(
                  'Before', HistoryItemCard.formatSize(item.originalSize)),
            ),
            Expanded(child: Container()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_forward,
                      color: AppColors.error, size: 20),
                  const SizedBox(height: 4),
                  Text('-${item.compressionRatio.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(child: Container()),
            Align(
              alignment: Alignment.centerRight,
              child: _buildSizeInfo(
                  'After', HistoryItemCard.formatSize(item.compressedSize),
                  isHighlight: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: style == HistoryDetailStyle.dialog
                ? const Color(0xFF1E1E1E)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (item.originalResolution.isNotEmpty)
                _buildCompareRow(
                  'Resolution',
                  item.originalResolution,
                  item.compressedResolution.isNotEmpty
                      ? item.compressedResolution
                      : item.originalResolution,
                ),
              _buildCompareRow(
                'Bitrate',
                item.originalBitrateFormatted,
                item.compressedBitrateFormatted,
              ),
              _buildCompareRow(
                'Frame Rate',
                item.frameRateFormatted,
                _getCompressedFrameRateFormatted(item.frameRate),
              ),
              if (item.duration > 0)
                _buildSingleRow('Duration', item.durationFormatted),
              _buildSingleRow('Compressed At',
                  HistoryItemCard.formatDate(item.compressedAt)),
            ],
          ),
        ),
        if (style == HistoryDetailStyle.dialog) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: item.outputPath.isNotEmpty
                    ? () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => VideoPlayerPage(
                                    videoPath: item.outputPath)));
                      }
                    : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: item.outputPath.isNotEmpty
                    ? () => _openFileLocation(item.outputPath)
                    : null,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Open Folder'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: item.outputPath.isNotEmpty
                    ? () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => VideoPlayerPage(
                                    videoPath: item.outputPath)));
                      }
                    : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              if (showSaveToGallery)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: item.outputPath.isNotEmpty
                        ? () => _saveToGallery(context, item)
                        : null,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Save to Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    final textColor = style == HistoryDetailStyle.dialog
        ? Colors.white
        : AppColors.textPrimary;
    final secondaryColor = style == HistoryDetailStyle.dialog
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: secondaryColor, fontSize: 12)),
        const SizedBox(height: 4),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _buildCompareRow(String label, String before, String after) {
    final secondaryColor = style == HistoryDetailStyle.dialog
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.textSecondary;
    final textColor = style == HistoryDetailStyle.dialog
        ? Colors.white
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(label,
                style: TextStyle(color: secondaryColor, fontSize: 12)),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: Text(before,
                style: TextStyle(color: secondaryColor, fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Icon(Icons.arrow_forward, color: secondaryColor, size: 14),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(after,
                style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleRow(String label, String value) {
    final secondaryColor = style == HistoryDetailStyle.dialog
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.textSecondary;
    final textColor = style == HistoryDetailStyle.dialog
        ? Colors.white
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getCompressedFrameRateFormatted(double? originalFrameRate) {
    if (originalFrameRate == null || originalFrameRate <= 0) return 'N/A';
    final compressedFrameRate =
        originalFrameRate > 30 ? 30.0 : originalFrameRate;
    return '${compressedFrameRate.toStringAsFixed(0)} fps';
  }

  Future<void> _saveToGallery(BuildContext context, HistoryItem item) async {
    try {
      await Gal.putVideo(item.outputPath);
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.success(context, 'Video saved to gallery');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to save: $e');
      }
    }
  }

  void _openFileLocation(String path) {
    if (path.isEmpty) return;
    if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', ['/select,$path']);
    } else if (Platform.isLinux) {
      final lastIndex = path.lastIndexOf('/');
      if (lastIndex > 0) {
        final dir = path.substring(0, lastIndex);
        Process.run('xdg-open', [dir]);
      }
    }
  }
}
