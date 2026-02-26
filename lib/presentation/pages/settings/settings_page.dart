/// Settings page UI implementation.
///
/// This page provides the user interface for configuring application settings
/// including default compression quality, output resolution, and cache management.
/// Uses BLoC pattern for state management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../utils/app_toast.dart';
import 'settings_bloc.dart';
import 'settings_state.dart';

/// Settings page widget for configuring application preferences.
///
/// Displays settings organized into sections:
/// - Default Settings: Quality and resolution presets
/// - Storage: Output directory and cache management
/// - About: Application version and information
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              _buildSection(
                title: 'Default Settings',
                children: [
                  _buildDropdownTile(
                    title: AppStrings.defaultQuality,
                    value: state.defaultQuality,
                    items: const ['Low', 'Medium', 'High'],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SettingsBloc>().add(
                              SetDefaultQuality(value),
                            );
                      }
                    },
                  ),
                  _buildDropdownTile(
                    title: AppStrings.defaultResolution,
                    value: state.defaultResolution,
                    items: const ['480P', '720P', '1080P', 'Original'],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SettingsBloc>().add(
                              SetDefaultResolution(value),
                            );
                      }
                    },
                  ),
                ],
              ),
              _buildSection(
                title: 'Storage',
                children: [
                  ListTile(
                    title: const Text(
                      AppStrings.outputDirectory,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      state.outputDirectory.isEmpty
                          ? 'Loading...'
                          : state.outputDirectory,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.folder_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      AppStrings.clearCache,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Cache: ${_formatCacheSize(state.cacheSize)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(
                      Icons.cleaning_services_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () {
                      context.read<SettingsBloc>().add(ClearCache());
                      AppToast.success(context, 'Cache cleared');
                    },
                  ),
                ],
              ),
              _buildSection(
                title: 'About',
                children: [
                  const ListTile(
                    title: Text(
                      'Version',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      AppStrings.about,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Video Compressor',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2024',
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds a settings section with a title and list of children.
  ///
  /// [title] - The section header text displayed in primary color.
  /// [children] - List of widgets (typically ListTiles) for this section.
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(color: AppColors.divider),
      ],
    );
  }

  /// Builds a dropdown list tile for selecting from a list of options.
  ///
  /// [title] - The label text displayed on the left.
  /// [value] - The currently selected value.
  /// [items] - List of available options to choose from.
  /// [onChanged] - Callback when the selection changes.
  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.surface,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// Formats a byte count into a human-readable string.
  ///
  /// Converts bytes to KB or MB with appropriate units.
  ///
  /// [bytes] - The size in bytes to format.
  /// Returns a formatted string like "1.5 MB" or "256 KB".
  String _formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
