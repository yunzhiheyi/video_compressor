/// 历史记录功能状态管理
///
/// 定义压缩历史功能的状态类。
/// 使用 BLoC 模式和 Equatable 实现高效的状态比较。
library;

import 'package:equatable/equatable.dart';

/// 历史记录功能的主状态类
///
/// 包含在历史页面显示的压缩历史记录列表。
/// 继承 [Equatable] 以在 BLoC 中实现高效的状态比较。
class HistoryState extends Equatable {
  /// 历史记录项列表，代表过去的压缩操作
  final List<HistoryItem> items;

  /// 创建新的 [HistoryState]，使用给定的记录列表
  ///
  /// 如果未提供记录，默认为空列表。
  const HistoryState({this.items = const []});

  /// 创建当前状态的副本，可选择更新部分字段
  ///
  /// [items] - 如果提供，替换当前的记录列表
  HistoryState copyWith({List<HistoryItem>? items}) {
    return HistoryState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}

/// 代表单个压缩历史记录条目
///
/// 包含已完成压缩操作的所有信息，
/// 包括文件大小、时间戳、分辨率、码率、帧率信息。
class HistoryItem extends Equatable {
  /// 历史记录的唯一标识符
  final String id;

  /// 压缩视频的原始文件名
  final String name;

  /// 压缩前的原始文件大小（字节）
  final int originalSize;

  /// 压缩后的文件大小（字节）
  final int compressedSize;

  /// 压缩完成的日期时间
  final DateTime compressedAt;

  /// 压缩输出文件的完整路径
  final String outputPath;

  /// 原始视频分辨率（如 "1920x1080"）
  final String originalResolution;

  /// 压缩后视频分辨率（如 "1280x720"）
  final String compressedResolution;

  /// 视频时长（秒）
  final double duration;

  /// 原始码率（bps）
  final int originalBitrate;

  /// 压缩后码率（bps）
  final int compressedBitrate;

  /// 帧率（fps）
  final double frameRate;

  /// 创建新的 [HistoryItem]，使用指定的属性
  const HistoryItem({
    required this.id,
    required this.name,
    required this.originalSize,
    required this.compressedSize,
    required this.compressedAt,
    required this.outputPath,
    this.originalResolution = '',
    this.compressedResolution = '',
    this.duration = 0,
    this.originalBitrate = 0,
    this.compressedBitrate = 0,
    this.frameRate = 0,
  });

  /// 计算压缩比例（百分比）
  ///
  /// 返回通过压缩节省的空间百分比。
  /// 例如，如果文件从 100MB 减少到 30MB，
  /// 压缩比例将是 70%。
  ///
  /// 如果 [originalSize] 为 0，返回 0 以避免除零错误。
  double get compressionRatio {
    if (originalSize == 0) return 0;
    return (1 - compressedSize / originalSize) * 100;
  }

  /// 格式化时长
  String get durationFormatted {
    if (duration <= 0) return '00:00';
    final h = (duration / 3600).floor();
    final m = ((duration % 3600) / 60).floor();
    final s = (duration % 60).floor();
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化原始码率
  String get originalBitrateFormatted => _formatBitrate(originalBitrate);

  /// 格式化压缩后码率
  String get compressedBitrateFormatted => _formatBitrate(compressedBitrate);

  /// 格式化帧率
  String get frameRateFormatted {
    if (frameRate <= 0) return 'N/A';
    return '${frameRate.toStringAsFixed(0)} fps';
  }

  String _formatBitrate(int bitrate) {
    if (bitrate <= 0) return 'N/A';
    if (bitrate >= 1000000) {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    } else if (bitrate >= 1000) {
      return '${(bitrate / 1000).toStringAsFixed(0)} Kbps';
    }
    return '$bitrate bps';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        originalSize,
        compressedSize,
        compressedAt,
        outputPath,
        originalResolution,
        compressedResolution,
        duration,
        originalBitrate,
        compressedBitrate,
        frameRate,
      ];
}
