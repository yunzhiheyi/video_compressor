import 'package:bottom_bar_matu/bottom_bar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_compressor/presentation/widgets/bottom_bar_double_bullet.dart';
import '../../../../core/constants/app_colors.dart';
import '../home_bloc.dart';
import '../home_event.dart';
import '../home_state.dart';
import '../../history/history_bloc.dart';
import '../../settings/settings_bloc.dart';
import 'compress_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeMobilePage extends StatefulWidget {
  const HomeMobilePage({super.key});

  @override
  State<HomeMobilePage> createState() => _HomeMobilePageState();
}

class _HomeMobilePageState extends State<HomeMobilePage> {
  @override
  void initState() {
    super.initState();
    context.read<HistoryBloc>().add(LoadHistory());
    context.read<SettingsBloc>().add(LoadSettings());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(
            index: state.currentIndex,
            children: const [
              MobileCompressPage(),
              MobileHistoryPage(),
              MobileSettingsPage(),
            ],
          ),
          bottomNavigationBar: Container(
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child:  BottomBarDoubleBullet(
                  selectedIndex: state.currentIndex,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  height: 60,
                  onSelect: (index) {
                    context.read<HomeBloc>().add(HomeTabChanged(index));
                    if (index == 1) {
                      context.read<HistoryBloc>().add(LoadHistory());
                    }
                    if (index == 2) {
                      context.read<SettingsBloc>().add(LoadSettings());
                    }
                  },
                  items: [
                    BottomBarItem(iconData: Icons.home, iconSize: 26),
                    BottomBarItem(iconData: Icons.history, iconSize: 26),
                    BottomBarItem(iconData: Icons.settings, iconSize: 26),
                  ],
                ),
              ),
          ),
        );
      },
    );
  }
}
