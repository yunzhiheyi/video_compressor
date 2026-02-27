import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../pages/history/history_state.dart';

class HistoryItemCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback? onTap;

  const HistoryItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      _buildSizeInfo('Before', _formatSize(item.originalSize)),
                ),
                Expanded(child: Container()),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward,
                        color: AppColors.error, size: 16),
                    const SizedBox(height: 2),
                    Text('-${item.compressionRatio.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 10)),
                  ],
                ),
                Expanded(child: Container()),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildSizeInfo(
                      'After', _formatSize(item.compressedSize),
                      isHighlight: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(item.compressedAt),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  static String formatSize(int bytes) => _formatSize(bytes);

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatDate(DateTime date) => _formatDate(date);

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
