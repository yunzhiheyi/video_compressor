import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';

/// FFmpeg服务类
/// 负责视频信息获取和视频压缩功能
class FFmpegService {
  /// 进度映射表，存储每个任务的压缩进度
  final Map<String, double> _progressMap = {};

  /// 会话ID映射表，存储每个任务的FFmpeg会话ID
  final Map<String, int> _sessionIdMap = {};

  /// 获取视频信息
  /// [path] 视频文件路径
  /// 返回包含视频元数据的Map
  Future<Map<String, dynamic>> getVideoInfo(String path) async {
    debugPrint('[FFmpegService] Getting video info for: $path');

    try {
      // 使用FFprobe获取视频详细信息
      final session = await FFprobeKit.execute(
          '-v quiet -print_format json -show_format -show_streams "$path"');
      final json = await session.getOutput();
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return _parseFFprobeOutput(json ?? '', path);
      }
    } catch (e) {
      debugPrint('[FFmpegService] FFprobe failed: $e');
    }

    // 如果FFprobe失败，返回基本信息
    return _getBasicVideoInfo(path);
  }

  /// 解析FFprobe输出的JSON数据
  Map<String, dynamic> _parseFFprobeOutput(String json, String path) {
    try {
      final lines = json.split('\n');
      String? duration;
      String? width;
      String? height;
      String? codec;
      String? bitrate;
      int? size;

      // 逐行解析JSON数据
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('"duration":')) {
          duration = trimmed
              .split(':')[1]
              .replaceAll('"', '')
              .replaceAll(',', '')
              .trim();
        }
        if (trimmed.startsWith('"width":')) {
          width = trimmed.split(':')[1].replaceAll(',', '').trim();
        }
        if (trimmed.startsWith('"height":')) {
          height = trimmed.split(':')[1].replaceAll(',', '').trim();
        }
        if (trimmed.startsWith('"codec_name":')) {
          codec ??= trimmed
              .split(':')[1]
              .replaceAll('"', '')
              .replaceAll(',', '')
              .trim();
        }
        if (trimmed.startsWith('"bit_rate":')) {
          bitrate = trimmed
              .split(':')[1]
              .replaceAll('"', '')
              .replaceAll(',', '')
              .trim();
        }
        if (trimmed.startsWith('"size":')) {
          final sizeStr = trimmed
              .split(':')[1]
              .replaceAll('"', '')
              .replaceAll(',', '')
              .trim();
          final sizeDouble = double.tryParse(sizeStr);
          size = sizeDouble?.toInt();
        }
      }

      return {
        'path': path,
        'name': path.split('/').last,
        'size': size,
        'duration': duration != null ? double.tryParse(duration) : null,
        'width': width != null ? int.tryParse(width) : null,
        'height': height != null ? int.tryParse(height) : null,
        'codec': codec,
        'bitrate': bitrate != null ? int.tryParse(bitrate) : null,
      };
    } catch (e) {
      debugPrint('[FFmpegService] Parse error: $e');
      return _getBasicVideoInfo(path);
    }
  }

  /// 获取视频基本信息（仅文件大小）
  Map<String, dynamic> _getBasicVideoInfo(String path) {
    final file = File(path);
    final stat = file.statSync();
    return {
      'path': path,
      'name': path.split('/').last,
      'size': stat.size,
      'duration': null,
      'width': null,
      'height': null,
      'codec': null,
      'bitrate': null,
    };
  }

  /// 提取视频缩略图（桌面端使用）
  /// [videoPath] 视频文件路径
  /// 返回缩略图的字节数据
  Future<Uint8List?> extractThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 只截取第一帧，不缩放
      final command =
          '-ss 0 -i "$videoPath" -vframes 1 -q:v 2 -y "$thumbnailPath"';

      debugPrint('[FFmpegService] Extracting thumbnail');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          final bytes = await thumbnailFile.readAsBytes();
          await thumbnailFile.delete();
          debugPrint(
              '[FFmpegService] Thumbnail extracted, size: ${bytes.length} bytes');
          return bytes;
        }
      }

      debugPrint('[FFmpegService] Failed to extract thumbnail');
      return null;
    } catch (e) {
      debugPrint('[FFmpegService] Thumbnail extraction error: $e');
      return null;
    }
  }

  /// 压缩视频
  /// [inputPath] 输入文件路径
  /// [outputPath] 输出文件路径
  /// [bitrate] 目标比特率
  /// [width] 目标宽度（可选）
  /// [height] 目标高度（可选）
  /// [taskId] 任务ID（可选）
  /// [originalWidth] 原始视频宽度（用于保持宽高比）
  /// [originalHeight] 原始视频高度（用于保持宽高比）
  /// 返回压缩进度流，0.0-1.0
  Stream<double> compressVideo({
    required String inputPath,
    required String outputPath,
    required int bitrate,
    int? width,
    int? height,
    String? taskId,
    int? originalWidth,
    int? originalHeight,
  }) async* {
    final id = taskId ?? DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[FFmpegService] ========== STARTING COMPRESSION ==========');
    debugPrint('[FFmpegService] Task ID: $id');
    debugPrint('[FFmpegService] Input: $inputPath');

    // 检查输入文件是否存在
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('Input file does not exist: $inputPath');
    }
    debugPrint(
        '[FFmpegService] Input file size: ${await inputFile.length()} bytes');

    // 确保输出目录存在
    if (outputPath.isEmpty) {
      throw Exception('Output path is empty');
    }
    final outputFile = File(outputPath);
    final outputDir = outputFile.parent;
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    debugPrint('[FFmpegService] Output: $outputPath');

    // 获取视频时长
    double? duration;
    int? originalBitrate;
    try {
      final durationSession = await FFprobeKit.execute(
          '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$inputPath"');
      final durationOutput = await durationSession.getOutput();
      if (durationOutput != null && durationOutput.trim().isNotEmpty) {
        duration = double.tryParse(durationOutput.trim());
        debugPrint('[FFmpegService] Duration: $duration seconds');
      }
    } catch (e) {
      debugPrint('[FFmpegService] Failed to get duration: $e');
    }

    // 获取原始视频比特率
    try {
      final bitrateSession = await FFprobeKit.execute(
          '-v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$inputPath"');
      final bitrateOutput = await bitrateSession.getOutput();
      if (bitrateOutput != null && bitrateOutput.trim().isNotEmpty) {
        originalBitrate = int.tryParse(bitrateOutput.trim());
        debugPrint('[FFmpegService] Original bitrate: $originalBitrate bps');
      }
    } catch (e) {
      debugPrint('[FFmpegService] Failed to get bitrate: $e');
    }

    // 智能比特率调整：如果原视频比特率低于目标，使用原视频的85%
    int actualBitrate = bitrate;
    if (originalBitrate != null && originalBitrate > 0 && bitrate > 0) {
      if (originalBitrate <= bitrate) {
        actualBitrate = (originalBitrate * 0.85).toInt();
        debugPrint(
            '[FFmpegService] Original bitrate lower than target, using $actualBitrate bps');
      }
    }

    final command = _buildCompressCommand(inputPath, outputPath, actualBitrate,
        width, height, originalWidth, originalHeight);
    debugPrint('[FFmpegService] Command: $command');

    yield 0.0;

    final completer = Completer<void>();
    double lastProgress = 0.0;
    bool hasError = false;
    String? errorMessage;
    int? sessionId;

    try {
      // 异步执行FFmpeg命令，并保存会话ID
      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          final output = await session.getOutput();

          debugPrint(
              '[FFmpegService] Task $id Completed. ReturnCode: $returnCode');

          if (ReturnCode.isSuccess(returnCode)) {
            debugPrint('[FFmpegService] Task $id SUCCESS!');
            _progressMap[id] = 1.0;
          } else {
            debugPrint('[FFmpegService] Task $id FAILED! Output: $output');
            _progressMap[id] = -1.0;
            hasError = true;
            errorMessage = output ?? 'FFmpeg error';
          }

          // 清理会话ID映射
          _sessionIdMap.remove(id);

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        null,
        // 统计回调，用于获取压缩进度
        (Statistics statistics) {
          final time = statistics.getTime();
          debugPrint(
              '[FFmpegService] Statistics callback: time=$time ms, duration=$duration');

          if (time > 0) {
            double progress;
            if (duration != null && duration > 0) {
              // 根据已处理时间和总时长计算进度
              progress = (time / 1000.0) / duration;
            } else {
              // 无法获取时长时，使用比特率估算
              debugPrint(
                  '[FFmpegService] Duration is null, using bitrate-based estimation');
              final bitrate = statistics.getBitrate();
              if (bitrate > 0) {
                final size = statistics.getSize();
                if (size > 0) {
                  progress = 0.5;
                } else {
                  progress = (time / 1000.0) / 300.0;
                }
              } else {
                progress = (time / 1000.0) / 300.0;
              }
            }
            final clampedProgress = progress.clamp(0.0, 0.99);
            _progressMap[id] = clampedProgress;
            debugPrint(
                '[FFmpegService] Progress updated: ${(clampedProgress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      // 保存会话ID，用于后续取消任务
      sessionId = session.getSessionId();
      if (sessionId != null) {
        _sessionIdMap[id] = sessionId;
        debugPrint(
            '[FFmpegService] Task $id started with session ID: $sessionId');
      }
    } catch (e) {
      debugPrint('[FFmpegService] Exception: $e');
      hasError = true;
      errorMessage = e.toString();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    // 等待压缩完成，同时yield进度
    var waitCount = 0;
    const maxWait = 1200; // 最大等待120秒
    while (!completer.isCompleted && waitCount < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;

      final progress = _progressMap[id];
      if (progress != null && progress > lastProgress) {
        yield progress;
        lastProgress = progress;
      }

      // 检查是否出错
      if (progress != null && progress < 0) {
        throw Exception(errorMessage ?? 'Compression failed');
      }
    }

    // 超时处理：只取消当前任务
    if (!completer.isCompleted) {
      if (sessionId != null) {
        debugPrint(
            '[FFmpegService] Task $id timeout, canceling session: $sessionId');
        await FFmpegKit.cancel(sessionId);
        _sessionIdMap.remove(id);
      }
      throw Exception('Compression timeout');
    }

    _progressMap.remove(id);

    if (hasError) {
      throw Exception(errorMessage ?? 'Compression failed');
    }

    debugPrint('[FFmpegService] ========== COMPLETE ==========');
    yield 1.0;
  }

  /// 构建FFmpeg压缩命令
  /// [inputPath] 输入路径
  /// [outputPath] 输出路径
  /// [bitrate] 目标比特率
  /// [targetWidth] 目标宽度
  /// [targetHeight] 目标高度
  /// [originalWidth] 原始视频宽度
  /// [originalHeight] 原始视频高度
  String _buildCompressCommand(
    String inputPath,
    String outputPath,
    int bitrate,
    int? targetWidth,
    int? targetHeight,
    int? originalWidth,
    int? originalHeight,
  ) {
    final buffer = StringBuffer();
    buffer.write('-i "$inputPath"');

    String videoCodec;
    if (Platform.isAndroid) {
      videoCodec = 'libx264';
    } else {
      videoCodec = 'h264_videotoolbox';
    }
    buffer.write(' -c:v $videoCodec');

    // 比特率控制
    final targetBitrate = bitrate <= 0 ? 2500000 : bitrate;
    buffer.write(' -b:v $targetBitrate');
    buffer.write(' -maxrate ${(targetBitrate * 1.3).toInt()}');
    buffer.write(' -bufsize ${(targetBitrate * 2.5).toInt()}');

    // 使用High Profile以获得更好的质量
    buffer.write(' -profile:v high');
    buffer.write(' -level 4.2');

    // 音频编码设置
    buffer.write(' -c:a aac');
    buffer.write(' -b:a 128k');

    // 分辨率缩放 - 保持原始宽高比
    // 根据原始视频方向和目标分辨率计算正确的缩放参数
    String? scaleFilter;

    if (targetWidth != null || targetHeight != null) {
      if (originalWidth != null &&
          originalHeight != null &&
          originalWidth > 0 &&
          originalHeight > 0) {
        // 判断视频是横屏还是竖屏
        final isLandscape = originalWidth >= originalHeight;

        if (targetHeight != null && targetWidth == null) {
          // 只指定了高度（如720p），根据视频方向自动计算宽度
          if (isLandscape) {
            // 横屏视频：目标高度固定，宽度按比例计算
            scaleFilter = 'scale=-2:$targetHeight';
            debugPrint(
                '[FFmpegService] Landscape video: scaling to height $targetHeight, width auto');
          } else {
            // 竖屏视频：目标高度变为宽度，高度按比例计算
            // 720p for 竖屏 means width=720
            scaleFilter = 'scale=$targetHeight:-2';
            debugPrint(
                '[FFmpegService] Portrait video: scaling to width $targetHeight, height auto');
          }
        } else if (targetWidth != null && targetHeight == null) {
          // 只指定了宽度
          scaleFilter = 'scale=$targetWidth:-2';
          debugPrint(
              '[FFmpegService] Scaling to width $targetWidth, height auto');
        } else if (targetWidth != null && targetHeight != null) {
          // 同时指定了宽高，使用force_original_aspect_ratio=decrease保持比例
          scaleFilter =
              'scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease';
          debugPrint(
              '[FFmpegService] Scaling to fit within $targetWidth x $targetHeight, keeping aspect ratio');
        }
      } else {
        // 没有原始视频信息，使用安全的缩放方式
        if (targetHeight != null) {
          scaleFilter = 'scale=-2:$targetHeight';
        } else if (targetWidth != null) {
          scaleFilter = 'scale=$targetWidth:-2';
        }
      }
    }

    if (scaleFilter != null) {
      buffer.write(' -vf "$scaleFilter"');
    }

    // 优化MP4播放
    buffer.write(' -movflags +faststart');
    buffer.write(' -y "$outputPath"');

    return buffer.toString();
  }

  /// 取消压缩任务
  /// [taskId] 任务ID
  Future<void> cancelCompress(String taskId) async {
    final sessionId = _sessionIdMap[taskId];
    if (sessionId != null) {
      debugPrint(
          '[FFmpegService] Canceling task $taskId with session ID: $sessionId');
      await FFmpegKit.cancel(sessionId);
      _sessionIdMap.remove(taskId);
    }
    _progressMap[taskId] = -1.0;
  }

  /// 释放资源
  void dispose() {
    _progressMap.clear();
    _sessionIdMap.clear();
  }
}
