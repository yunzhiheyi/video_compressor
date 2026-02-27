import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/history_item_card.dart';
import '../../../widgets/history_detail_content.dart';
import '../../history/history_bloc.dart';
import '../../history/history_state.dart';

class DesktopHistoryPage extends StatelessWidget {
  const DesktopHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compression History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    if (state.items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _showClearConfirmation(context),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Clear All'),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: state.items.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryGrid(context, state.items),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No compression history',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid(BuildContext context, List<HistoryItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardWidth = 320.0;
        const spacing = 16.0;
        final crossAxisCount =
            (constraints.maxWidth / cardWidth).floor().clamp(1, 4);
        final actualCardWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * spacing - 48) /
                crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: spacing,
            runSpacing: 12,
            children: items
                .map((item) => SizedBox(
                      width: actualCardWidth,
                      child: _buildHistoryCard(context, item),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryItem item) {
    return GestureDetector(
      onTap: () => HistoryDetailContent.show(
        context,
        item: item,
        style: HistoryDetailStyle.dialog,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2D2D2D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSizeInfo(
                      'Before', HistoryItemCard.formatSize(item.originalSize)),
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
                  _buildSizeInfo(
                      'After', HistoryItemCard.formatSize(item.compressedSize),
                      isHighlight: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(HistoryItemCard.formatDate(item.compressedAt),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeInfo(String label, String size, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        const SizedBox(height: 2),
        Text(size,
            style: TextStyle(
              color: isHighlight ? AppColors.success : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title:
            const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear all history?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(ClearHistory());
              Navigator.pop(context);
            },
            child:
                const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
