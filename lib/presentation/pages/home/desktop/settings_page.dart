import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../settings/settings_bloc.dart';
import '../../settings/settings_state.dart';
import '../../../widgets/settings_sections.dart';

class DesktopSettingsPage extends StatelessWidget {
  const DesktopSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return SettingsSections(
            style: SettingsStyle.desktop,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
          );
        },
      ),
    );
  }
}
