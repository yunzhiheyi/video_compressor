/// 历史记录页面UI实现
///
/// 该页面展示所有已压缩视频的历史记录，包括原始/压缩后大小和压缩比率。
/// 用户可以查看详情、删除单条记录或清除所有历史记录。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'history_bloc.dart';
import 'history_state.dart';

/// 历史记录页面组件
///
/// 展示 [HistoryItem] 列表，包括：
/// - 视频文件名
/// - 压缩比率标签
/// - 原始和压缩后大小
/// - 压缩时间戳
///
/// 当没有历史记录时显示空状态。
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

  /// 构建空状态显示
  ///
  /// 显示历史图标和提示信息。
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

  /// 构建历史记录列表
  ///
  /// [items] - 要展示的 [HistoryItem] 列表。
  Widget _buildHistoryList(List<HistoryItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildHistoryItem(context, item);
      },
    );
  }

  /// 构建单个历史记录卡片
  ///
  /// 展示视频名称、压缩比率、大小比较和压缩日期。点击显示详细信息。
  ///
  /// [item] - 要展示的 [HistoryItem]。
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

  /// 显示历史记录的详情底部表单
  ///
  /// 展示所有可用信息，包括：
  /// - 文件名
  /// - 原始和压缩后大小
  /// - 压缩比率
  /// - 压缩日期
  /// - 分辨率信息（如有）
  /// - 输出文件路径
  /// - 删除按钮
  ///
  /// [item] - 要展示详情的 [HistoryItem]。
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

  /// 构建详情底部表单中的单行
  ///
  /// [label] - 左侧显示的标签文本
  /// [value] - 右侧显示的值文本
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

  /// 显示删除历史记录前的确认对话框
  ///
  /// [item] - 要删除的 [HistoryItem]。
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

  /// 格式化字节数为可读字符串
  ///
  /// 将字节转换为 B, KB, MB 或 GB 并选择合适的单位
  ///
  /// [bytes] - 要格式化的字节大小
  /// 返回格式化后的字符串，如 "1.50 MB" 或 "256.0 KB"
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 格式化日期时间为可读字符串
  ///
  /// 格式: "YYYY-MM-DD HH:MM"
  ///
  /// [date] - 要格式化的 DateTime
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 显示清除所有历史记录前的确认对话框
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
