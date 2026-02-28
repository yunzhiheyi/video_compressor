/// 设置页面UI实现
///
/// 该页面提供配置应用程序设置的界面，包括默认压缩质量、输出分辨率和缓存管理。
/// 使用BLoC模式进行状态管理。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../utils/app_toast.dart';
import 'settings_bloc.dart';
import 'settings_state.dart';

/// 设置页面组件，用于配置应用程序首选项
///
/// 展示分组后的设置项：
/// - 默认设置：质量和分辨率预设
/// - 存储：输出目录和缓存管理
/// - 关于：应用程序版本和信息
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

  /// 构建设置分区，包含标题和子组件列表
  ///
  /// [title] - 以主色显示的分区标题文本
  /// [children] - 该分区的组件列表（通常为 ListTiles）
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

  /// 构建下拉列表瓦片，用于从选项列表中选择
  ///
  /// [title] - 左侧显示的标签文本
  /// [value] - 当前选中的值
  /// [items] - 可供选择的选项列表
  /// [onChanged] - 选择变更时的回调
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

  /// 格式化字节数为可读字符串
  ///
  /// 将字节转换为 KB 或 MB 并选择合适的单位
  ///
  /// [bytes] - 要格式化的字节大小
  /// 返回格式化后的字符串，如 "1.5 MB" 或 "256 KB"
  String _formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
