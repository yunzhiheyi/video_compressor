/// 压缩任务数据模型
///
/// 用于跟踪视频压缩任务的状态和进度，包括：
/// - 任务ID和关联的视频信息
/// - 压缩配置
/// - 当前状态和进度
/// - 压缩结果（输出路径、压缩后大小等）
import 'package:equatable/equatable.dart';
import 'video_info.dart';
import 'compress_config.dart';

/// 压缩任务状态枚举
enum CompressTaskStatus {
  pending, // 等待中
  queued, // 已排队
  running, // 进行中
  completed, // 已完成
  failed, // 失败
  cancelled, // 已取消
  skipped // 已跳过
}

/// 压缩任务模型类
class CompressTask extends Equatable {
  /// 任务唯一标识符
  final String id;

  /// 待压缩的视频信息
  final VideoInfo video;

  /// 压缩配置
  final CompressConfig config;

  /// 当前任务状态
  final CompressTaskStatus status;

  /// 压缩进度（0.0 - 1.0）
  final double progress;

  /// 压缩后输出文件路径
  final String? outputPath;

  /// 压缩后文件大小（字节）
  final int? compressedSize;

  /// 压缩后视频宽度
  final int? compressedWidth;

  /// 压缩后视频高度
  final int? compressedHeight;

  /// 压缩后视频比特率（实际使用的比特率）
  final int? compressedBitrate;

  /// 错误信息（失败时）
  final String? errorMessage;

  /// 跳过原因（跳过时）
  final String? skipReason;

  const CompressTask({
    required this.id,
    required this.video,
    required this.config,
    this.status = CompressTaskStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.compressedSize,
    this.compressedWidth,
    this.compressedHeight,
    this.compressedBitrate,
    this.errorMessage,
    this.skipReason,
  });

  /// 是否已完成
  bool get isComplete => status == CompressTaskStatus.completed;

  /// 是否失败
  bool get isFailed => status == CompressTaskStatus.failed;

  /// 是否进行中
  bool get isRunning => status == CompressTaskStatus.running;

  /// 是否等待中
  bool get isPending => status == CompressTaskStatus.pending;

  /// 是否已排队
  bool get isQueued => status == CompressTaskStatus.queued;

  /// 是否已跳过
  bool get isSkipped => status == CompressTaskStatus.skipped;

  /// 计算压缩比率（百分比）
  ///
  /// 返回值如 45.5 表示压缩后文件大小减少了 45.5%
  double get compressionRatio {
    if (compressedSize == null || video.size == null || video.size == 0) {
      return 0.0;
    }
    return (1 - (compressedSize! / video.size!)) * 100;
  }

  /// 原始分辨率字符串
  String get originalResolution => video.resolution;

  /// 压缩后分辨率字符串
  String get compressedResolution {
    if (compressedWidth == null || compressedHeight == null) {
      return 'Unknown';
    }
    return '${compressedWidth}x$compressedHeight';
  }

  /// 复制并修改部分属性
  CompressTask copyWith({
    String? id,
    VideoInfo? video,
    CompressConfig? config,
    CompressTaskStatus? status,
    double? progress,
    String? outputPath,
    int? compressedSize,
    int? compressedWidth,
    int? compressedHeight,
    int? compressedBitrate,
    String? errorMessage,
    String? skipReason,
  }) {
    return CompressTask(
      id: id ?? this.id,
      video: video ?? this.video,
      config: config ?? this.config,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      compressedSize: compressedSize ?? this.compressedSize,
      compressedWidth: compressedWidth ?? this.compressedWidth,
      compressedHeight: compressedHeight ?? this.compressedHeight,
      compressedBitrate: compressedBitrate ?? this.compressedBitrate,
      errorMessage: errorMessage ?? this.errorMessage,
      skipReason: skipReason ?? this.skipReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        video,
        config,
        status,
        progress,
        outputPath,
        compressedSize,
        compressedWidth,
        compressedHeight,
        compressedBitrate,
        errorMessage,
        skipReason,
      ];

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video': video.toJson(),
      'config': config.toJson(),
      'status': status.index,
      'progress': progress,
      'outputPath': outputPath,
      'compressedSize': compressedSize,
      'compressedWidth': compressedWidth,
      'compressedHeight': compressedHeight,
      'compressedBitrate': compressedBitrate,
      'errorMessage': errorMessage,
      'skipReason': skipReason,
    };
  }

  /// 从JSON Map创建实例
  factory CompressTask.fromJson(Map<String, dynamic> json) {
    return CompressTask(
      id: json['id'] as String,
      video: VideoInfo.fromJson(json['video'] as Map<String, dynamic>),
      config: CompressConfig.fromJson(json['config'] as Map<String, dynamic>),
      status: CompressTaskStatus.values[json['status'] as int? ?? 0],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      outputPath: json['outputPath'] as String?,
      compressedSize: json['compressedSize'] as int?,
      compressedWidth: json['compressedWidth'] as int?,
      compressedHeight: json['compressedHeight'] as int?,
      compressedBitrate: json['compressedBitrate'] as int?,
      errorMessage: json['errorMessage'] as String?,
      skipReason: json['skipReason'] as String?,
    );
  }
}
