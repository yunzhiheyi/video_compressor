/// 设置功能状态管理
///
/// 该文件定义了应用程序设置功能的状态类。包含用户对压缩质量、分辨率和存储的首选项。
library;

import 'package:equatable/equatable.dart';

/// 应用程序设置的状态类
///
/// 保存所有用户可配置的设置，这些设置会影响默认压缩行为和存储管理。
/// 继承 [Equatable] 以在 BLoC 中实现高效的状态比较
class SettingsState extends Equatable {
  /// 默认压缩质量预设
  ///
  /// 可能的值：'Low', 'Medium', 'High'
  final String defaultQuality;

  /// 压缩视频的默认输出分辨率
  ///
  /// 可能的值：'480P', '720P', '1080P', 'Original'
  final String defaultResolution;

  /// 压缩视频保存的目录路径
  ///
  /// 空字符串表示使用默认输出目录
  final String outputDirectory;

  /// 当前缓存大小（以字节为单位）
  ///
  /// 用于显示缓存使用情况并在需要时启用清除功能
  final int cacheSize;

  /// 使用指定设置创建新的 [SettingsState]
  ///
  /// 所有参数都有首次启动时的合理默认值
  const SettingsState({
    this.defaultQuality = 'Medium',
    this.defaultResolution = '1080P',
    this.outputDirectory = '',
    this.cacheSize = 0,
  });

  /// 创建此状态的副本，可选择更新字段
  ///
  /// 未提供的任何字段将保留其当前值
  SettingsState copyWith({
    String? defaultQuality,
    String? defaultResolution,
    String? outputDirectory,
    int? cacheSize,
  }) {
    return SettingsState(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultResolution: defaultResolution ?? this.defaultResolution,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      cacheSize: cacheSize ?? this.cacheSize,
    );
  }

  @override
  List<Object?> get props => [
        defaultQuality,
        defaultResolution,
        outputDirectory,
        cacheSize,
      ];
}
