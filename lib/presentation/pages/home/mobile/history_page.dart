import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../history/history_bloc.dart';
import '../../history/history_state.dart';
import '../../../widgets/history_item_card.dart';
import '../../../widgets/history_detail_content.dart';

class MobileHistoryPage extends StatelessWidget {
  const MobileHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: AppColors.surface,
        actions: [
          BlocBuilder<HistoryBloc, HistoryState>(
            builder: (context, state) {
              if (state.items.isNotEmpty) {
                return TextButton(
                  onPressed: () => _showClearConfirmation(context),
                  child: const Text('Clear All'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No compression history',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return HistoryItemCard(
                item: item,
                onTap: () => HistoryDetailContent.show(
                  context,
                  item: item,
                  style: HistoryDetailStyle.bottomSheet,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
