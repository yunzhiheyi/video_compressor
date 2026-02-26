/// History page UI implementation.
///
/// This page displays the compression history showing all previously
/// compressed videos with their original/compressed sizes and compression ratios.
/// Users can view details, delete individual records, or clear all history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'history_bloc.dart';
import 'history_state.dart';

/// History page widget for displaying compression records.
///
/// Shows a list of [HistoryItem]s with:
/// - Video file name
/// - Compression ratio badge
/// - Original and compressed sizes
/// - Compression timestamp
///
/// Empty state is shown when no history exists.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.history),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showClearConfirmation(context);
            },
          ),
        ],
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _buildEmptyState();
          }
          return _buildHistoryList(state.items);
        },
      ),
    );
  }

  /// Builds the empty state displayed when no history exists.
  ///
  /// Shows a history icon and helpful message to the user.
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            AppStrings.noHistory,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Builds the list of history items.
  ///
  /// [items] - The list of [HistoryItem]s to display.
  Widget _buildHistoryList(List<HistoryItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildHistoryItem(context, item);
      },
    );
  }

  /// Builds a single history item card.
  ///
  /// Displays the video name, compression ratio, size comparison,
  /// and compression date. Tapping shows detailed information.
  ///
  /// [item] - The [HistoryItem] to display.
  Widget _buildHistoryItem(BuildContext context, HistoryItem item) {
    return GestureDetector(
      onTap: () => _showItemDetail(context, item),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${item.compressionRatio.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Original',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          _formatSize(item.originalSize),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      color: AppColors.textSecondary, size: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Compressed',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          _formatSize(item.compressedSize),
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(item.compressedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a bottom sheet with detailed information about a history item.
  ///
  /// Displays all available information including:
  /// - File name
  /// - Original and compressed sizes
  /// - Compression ratio
  /// - Compression date
  /// - Resolution information (if available)
  /// - Output file path
  /// - Delete button
  ///
  /// [item] - The [HistoryItem] to show details for.
  void _showItemDetail(BuildContext context, HistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Original Size', _formatSize(item.originalSize)),
              _buildDetailRow(
                  'Compressed Size', _formatSize(item.compressedSize)),
              _buildDetailRow(
                  'Saved', '-${item.compressionRatio.toStringAsFixed(1)}%'),
              _buildDetailRow('Date', _formatDate(item.compressedAt)),
              if (item.originalResolution.isNotEmpty)
                _buildDetailRow('Original Resolution', item.originalResolution),
              if (item.compressedResolution.isNotEmpty)
                _buildDetailRow(
                    'Compressed Resolution', item.compressedResolution),
              _buildDetailRow('Output', item.outputPath),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(context, item);
                      },
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      label: const Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single row in the detail bottom sheet.
  ///
  /// [label] - The label text displayed on the left.
  /// [value] - The value text displayed on the right.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a history item.
  ///
  /// [item] - The [HistoryItem] to potentially delete.
  void _showDeleteConfirmation(BuildContext context, HistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete compression record for "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(DeleteHistoryItem(item.id));
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  /// Formats a byte count into a human-readable string.
  ///
  /// Converts bytes to B, KB, MB, or GB with appropriate units.
  ///
  /// [bytes] - The size in bytes to format.
  /// Returns a formatted string like "1.50 MB" or "256.0 KB".
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Formats a DateTime into a readable string.
  ///
  /// Format: "YYYY-MM-DD HH:MM"
  ///
  /// [date] - The DateTime to format.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Shows a confirmation dialog before clearing all history.
  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.clearHistory),
        content: const Text(AppStrings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(ClearHistory());
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
