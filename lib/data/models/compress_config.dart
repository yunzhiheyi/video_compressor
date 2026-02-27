/// 压缩配置数据模型
///
/// 定义视频压缩的配置参数：
/// - 画质等级（低、中、高、原始、自定义）
/// - 自定义码率
/// - 目标分辨率
/// - 帧率
import 'package:equatable/equatable.dart';

/// 压缩画质枚举
enum CompressQuality {
  low, // 低画质 (1 Mbps)
  medium, // 中画质 (2.5 Mbps)
  high, // 高画质 (5 Mbps)
  original, // 原始画质（不改变码率）
  custom // 自定义码率
}

/// 压缩配置模型类
class CompressConfig extends Equatable {
  /// 画质等级
  final CompressQuality quality;

  /// 自定义码率（仅当 quality 为 custom 时使用）
  final int? customBitrate;

  /// 目标宽度（像素）
  final int? targetWidth;

  /// 目标高度（像素）
  final int? targetHeight;

  /// 目标帧率
  final int? frameRate;

  /// 是否保持原始分辨率
  final bool keepOriginalResolution;

  const CompressConfig({
    this.quality = CompressQuality.medium,
    this.customBitrate,
    this.targetWidth,
    this.targetHeight,
    this.frameRate,
    this.keepOriginalResolution = true,
  });

  /// 获取码率值（bps）
  ///
  /// 根据画质等级返回对应的目标码率：
  /// - Low: 1 Mbps
  /// - Medium: 2.5 Mbps
  /// - High: 5 Mbps
  /// - Original: 0 (保持原码率)
  /// - Custom: 使用 customBitrate 值
  int get bitrate {
    switch (quality) {
      case CompressQuality.low:
        return 1000000;
      case CompressQuality.medium:
        return 2500000;
      case CompressQuality.high:
        return 5000000;
      case CompressQuality.original:
        return 0;
      case CompressQuality.custom:
        return customBitrate ?? 2500000;
    }
  }

  /// 获取画质标签文本
  String get qualityLabel {
    switch (quality) {
      case CompressQuality.low:
        return 'Low (1 Mbps)';
      case CompressQuality.medium:
        return 'Medium (2.5 Mbps)';
      case CompressQuality.high:
        return 'High (5 Mbps)';
      case CompressQuality.original:
        return 'Original';
      case CompressQuality.custom:
        return 'Custom (${(customBitrate ?? 0) ~/ 1000} Kbps)';
    }
  }

  /// 复制并修改部分属性
  CompressConfig copyWith({
    CompressQuality? quality,
    int? customBitrate,
    int? targetWidth,
    int? targetHeight,
    int? frameRate,
    bool? keepOriginalResolution,
  }) {
    return CompressConfig(
      quality: quality ?? this.quality,
      customBitrate: customBitrate ?? this.customBitrate,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      frameRate: frameRate ?? this.frameRate,
      keepOriginalResolution:
          keepOriginalResolution ?? this.keepOriginalResolution,
    );
  }

  @override
  List<Object?> get props => [
        quality,
        customBitrate,
        targetWidth,
        targetHeight,
        frameRate,
        keepOriginalResolution,
      ];

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'quality': quality.index,
      'customBitrate': customBitrate,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'frameRate': frameRate,
      'keepOriginalResolution': keepOriginalResolution,
    };
  }

  /// 从JSON Map创建实例
  factory CompressConfig.fromJson(Map<String, dynamic> json) {
    return CompressConfig(
      quality: CompressQuality.values[json['quality'] as int? ?? 1],
      customBitrate: json['customBitrate'] as int?,
      targetWidth: json['targetWidth'] as int?,
      targetHeight: json['targetHeight'] as int?,
      frameRate: json['frameRate'] as int?,
      keepOriginalResolution: json['keepOriginalResolution'] as bool? ?? true,
    );
  }
}
