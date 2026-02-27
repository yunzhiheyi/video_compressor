/// 视频信息数据模型
///
/// 存储视频的元数据信息，包括：
/// - 文件路径和名称
/// - 文件大小
/// - 时长
/// - 分辨率
/// - 编码格式
/// - 码率
/// - 缩略图数据
import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// 视频信息模型类
class VideoInfo extends Equatable {
  /// 视频文件路径
  final String path;

  /// 文件名
  final String? name;

  /// 文件大小（字节）
  final int? size;

  /// 视频时长
  final Duration? duration;

  /// 视频宽度（像素）
  final int? width;

  /// 视频高度（像素）
  final int? height;

  /// 视频编码格式（如 h264, hevc）
  final String? codec;

  /// 视频码率（bps）
  final int? bitrate;

  /// 帧率
  final double? frameRate;

  /// 旋转角度（0, 90, 180, 270）
  final int? rotation;

  /// 缩略图字节数据（移动端使用）
  final Uint8List? thumbnailBytes;

  const VideoInfo({
    required this.path,
    this.name,
    this.size,
    this.duration,
    this.width,
    this.height,
    this.codec,
    this.bitrate,
    this.frameRate,
    this.rotation,
    this.thumbnailBytes,
  });

  /// 获取分辨率字符串（如 "1920×1080"）
  ///
  /// 考虑旋转元数据，返回显示时的实际分辨率
  String get resolution {
    int? displayWidth = width;
    int? displayHeight = height;

    // 如果有 90 或 270 度旋转，交换宽高用于显示
    if (rotation != null && (rotation!.abs() == 90 || rotation!.abs() == 270)) {
      displayWidth = height;
      displayHeight = width;
    }

    return '${displayWidth ?? 0}×${displayHeight ?? 0}';
  }

  /// 获取格式化后的文件大小（如 "25.5 MB"）
  String get sizeFormatted => _formatFileSize(size ?? 0);

  /// 获取格式化后的时长（如 "01:30:45" 或 "05:30"）
  String get durationFormatted {
    if (duration == null) return '00:00';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60);
    final s = duration!.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 从JSON Map创建VideoInfo实例
  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      path: json['path'] ?? '',
      name: json['name'],
      size: (json['size'] as num?)?.toInt(),
      duration: json['duration'] != null
          ? Duration(milliseconds: (json['duration'] as num).toInt())
          : null,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      codec: json['codec'],
      bitrate: (json['bitrate'] as num?)?.toInt(),
      frameRate: (json['frameRate'] as num?)?.toDouble(),
      rotation: (json['rotation'] as num?)?.toInt(),
      thumbnailBytes: null,
    );
  }

  /// 转换为JSON Map
  ///
  /// 注意：thumbnailBytes 不持久化，因为 Uint8List 无法直接 JSON 序列化，
  /// 且缩略图可以在加载时重新从视频提取
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'duration': duration?.inMilliseconds,
      'width': width,
      'height': height,
      'codec': codec,
      'bitrate': bitrate,
      'frameRate': frameRate,
      'rotation': rotation,
    };
  }

  /// 复制并修改部分属性
  VideoInfo copyWith({
    String? path,
    String? name,
    int? size,
    Duration? duration,
    int? width,
    int? height,
    String? codec,
    int? bitrate,
    double? frameRate,
    int? rotation,
    Uint8List? thumbnailBytes,
  }) {
    return VideoInfo(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      frameRate: frameRate ?? this.frameRate,
      rotation: rotation ?? this.rotation,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    );
  }

  @override
  List<Object?> get props => [
        path,
        name,
        size,
        duration,
        width,
        height,
        codec,
        bitrate,
        frameRate,
        rotation,
        thumbnailBytes,
      ];
}
