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
    this.thumbnailBytes,
  });

  /// 获取分辨率字符串（如 "1920×1080"）
  String get resolution => '${width ?? 0}×${height ?? 0}';

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
          ? Duration(
              milliseconds:
                  ((json['duration'] as num).toDouble() * 1000).toInt())
          : null,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      codec: json['codec'],
      bitrate: (json['bitrate'] as num?)?.toInt(),
      frameRate: (json['frameRate'] as num?)?.toDouble(),
      thumbnailBytes: json['thumbnailBytes'] as Uint8List?,
    );
  }

  /// 转换为JSON Map
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
        thumbnailBytes,
      ];
}
