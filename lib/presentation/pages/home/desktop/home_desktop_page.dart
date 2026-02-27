import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../home_bloc.dart';
import '../home_event.dart';
import '../home_state.dart';
import '../../history/history_bloc.dart';
import '../../settings/settings_bloc.dart';
import 'compress_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeDesktopPage extends StatelessWidget {
  const HomeDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Row(
            children: [
              _buildSidebar(context, state),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),
              Expanded(
                child: IndexedStack(
                  index: state.currentIndex,
                  children: const [
                    DesktopCompressPage(),
                    DesktopHistoryPage(),
                    DesktopSettingsPage(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, HomeState state) {
    return Container(
      width: 220,
      color: const Color(0xFF252526),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Row(
              children: [
                Icon(Icons.compress, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Video Compressor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(context, Icons.home_outlined, Icons.home, 'Home',
                    0, state.currentIndex == 0),
                _buildNavItem(context, Icons.history_outlined, Icons.history,
                    'History', 1, state.currentIndex == 1),
                _buildNavItem(context, Icons.settings_outlined, Icons.settings,
                    'Settings', 2, state.currentIndex == 2),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, IconData activeIcon,
      String label, int index, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.7),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          context.read<HomeBloc>().add(HomeTabChanged(index));
          if (index == 1) context.read<HistoryBloc>().add(LoadHistory());
          if (index == 2) context.read<SettingsBloc>().add(LoadSettings());
        },
      ),
    );
  }
}
