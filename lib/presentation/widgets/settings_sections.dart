import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum SettingsStyle { mobile, desktop }

class SettingsSections extends StatelessWidget {
  final SettingsStyle style;
  final String defaultQuality;
  final String defaultResolution;
  final String outputDirectory;
  final int cacheSize;
  final Function(String) onQualityChanged;
  final Function(String) onResolutionChanged;
  final VoidCallback onClearCache;

  const SettingsSections({
    super.key,
    this.style = SettingsStyle.mobile,
    required this.defaultQuality,
    required this.defaultResolution,
    required this.outputDirectory,
    required this.cacheSize,
    required this.onQualityChanged,
    required this.onResolutionChanged,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    if (style == SettingsStyle.mobile) {
      return _buildMobileStyle(context);
    }
    return _buildDesktopStyle(context);
  }

  Widget _buildMobileStyle(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Default Settings',
            children: [
              _buildDropdownRow('Default Quality', defaultQuality,
                  const ['Low', 'Medium', 'High'], onQualityChanged),
              _buildDropdownRow(
                  'Default Resolution',
                  defaultResolution,
                  const ['480P', '720P', '1080P', 'Original'],
                  onResolutionChanged),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Storage',
            children: [
              _buildInfoRow('Output Directory',
                  outputDirectory.isEmpty ? 'Loading...' : outputDirectory),
              _buildActionRow('Clear Cache',
                  'Cache: ${_formatCacheSize(cacheSize)}', onClearCache),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'About',
            children: [
              _buildInfoRow('Version', '1.0.0'),
              _buildInfoRow('Build', '2026.2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStyle(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            _buildDesktopCard(
              title: 'Default Settings',
              children: [
                _buildDropdownRow('Default Quality', defaultQuality,
                    const ['Low', 'Medium', 'High'], onQualityChanged),
                _buildDropdownRow(
                    'Default Resolution',
                    defaultResolution,
                    const ['480P', '720P', '1080P', 'Original'],
                    onResolutionChanged),
              ],
            ),
            const SizedBox(height: 24),
            _buildDesktopCard(
              title: 'Storage',
              children: [
                _buildInfoRow('Output Directory',
                    outputDirectory.isEmpty ? 'Loading...' : outputDirectory),
                _buildActionRow('Clear Cache',
                    'Cache: ${_formatCacheSize(cacheSize)}', onClearCache),
              ],
            ),
            const SizedBox(height: 24),
            _buildDesktopCard(
              title: 'About',
              children: [
                _buildInfoRow('Version', '1.0.0'),
                _buildInfoRow('Build', '2026.2'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDesktopCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> items,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: style == SettingsStyle.desktop
                      ? Colors.white
                      : AppColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: style == SettingsStyle.desktop
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: style == SettingsStyle.desktop
                  ? const Color(0xFF2D2D2D)
                  : AppColors.surface,
              underline: const SizedBox(),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            style: TextStyle(
                                color: style == SettingsStyle.desktop
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: style == SettingsStyle.desktop
                      ? Colors.white70
                      : AppColors.textSecondary)),
          Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: style == SettingsStyle.desktop
                          ? Colors.white
                          : AppColors.textPrimary),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: style == SettingsStyle.desktop
                            ? Colors.white
                            : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: style == SettingsStyle.desktop
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.textSecondary,
                        fontSize: 12)),
              ],
            ),
            Icon(Icons.chevron_right,
                color: style == SettingsStyle.desktop
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
