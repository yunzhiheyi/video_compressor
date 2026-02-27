import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../utils/app_toast.dart';
import '../../settings/settings_bloc.dart';
import '../../settings/settings_state.dart';
import '../../../widgets/settings_sections.dart';

class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return SettingsSections(
            style: SettingsStyle.mobile,
            defaultQuality: state.defaultQuality,
            defaultResolution: state.defaultResolution,
            outputDirectory: state.outputDirectory,
            cacheSize: state.cacheSize,
            onQualityChanged: (value) {
              context.read<SettingsBloc>().add(SetDefaultQuality(value));
            },
            onResolutionChanged: (value) {
              context.read<SettingsBloc>().add(SetDefaultResolution(value));
            },
            onClearCache: () {
              context.read<SettingsBloc>().add(ClearCache());
              AppToast.success(context, 'Cache cleared');
            },
          );
        },
      ),
    );
  }
}
