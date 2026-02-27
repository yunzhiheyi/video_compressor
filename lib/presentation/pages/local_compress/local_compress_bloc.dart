/// 本地压缩业务逻辑控制器
///
/// 核心功能：
/// - 视频选择和管理
/// - 压缩任务队列管理（最多2个并发任务）
/// - 压缩进度跟踪
/// - 历史记录保存
/// - 默认配置加载
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/video_info.dart';
import '../../../data/models/compress_task.dart';
import '../../../data/models/compress_config.dart';
import '../../../services/ffmpeg_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/foreground_service.dart';
import 'local_compress_event.dart';
import 'local_compress_state.dart';

/// 本地压缩BLoC类
class LocalCompressBloc extends Bloc<LocalCompressEvent, LocalCompressState> {
  /// FFmpeg服务实例
  final FFmpegService _ffmpegService;

  /// 存储服务实例
  final StorageService _storageService;

  /// 前台服务实例
  final ForegroundService? _foregroundService;

  /// UUID生成器
  final Uuid _uuid = const Uuid();

  /// 任务进度订阅映射
  final Map<String, StreamSubscription> _subscriptions = {};

  /// 待处理任务队列
  final Queue<String> _pendingQueue = Queue();

  /// 最大并发任务数
  static const int _maxConcurrentTasks = 2;

  /// 当前运行中的任务数
  int _runningTasks = 0;

  LocalCompressBloc({
    required FFmpegService ffmpegService,
    required StorageService storageService,
    ForegroundService? foregroundService,
  })  : _ffmpegService = ffmpegService,
        _storageService = storageService,
        _foregroundService = foregroundService,
        super(const LocalCompressState()) {
    // 注册事件处理器
    on<SelectVideos>(_onSelectVideos);
    on<RemoveSelectedVideo>(_onRemoveSelectedVideo);
    on<UpdateCompressConfig>(_onUpdateConfig);
    on<StartCompress>(_onStartCompress);
    on<CancelCompress>(_onCancelCompress);
    on<RemoveTask>(_onRemoveTask);
    on<ClearCompleted>(_onClearCompleted);
    on<LoadDefaultConfig>(_onLoadDefaultConfig);
    on<LoadSavedTasks>(_onLoadSavedTasks);
    on<CheckRunningTasks>(_onCheckRunningTasks);
    on<ClearToastMessage>(_onClearToastMessage);
    on<RetryTask>(_onRetryTask);
    // 内部事件
    on<_StartTask>(_onStartTask);
    on<_UpdateTaskProgress>(_onUpdateTaskProgress);
    on<_TaskCompleted>(_onTaskCompleted);
    on<_ProcessQueue>(_onProcessQueue);
  }

  /// 加载默认配置
  ///
  /// 从本地存储读取用户设置的默认质量和分辨率
  void _onLoadDefaultConfig(
    LoadDefaultConfig event,
    Emitter<LocalCompressState> emit,
  ) {
    final qualityStr = _storageService.getDefaultQuality();
    final resolutionStr = _storageService.getDefaultResolution();

    CompressQuality quality = CompressQuality.medium;
    switch (qualityStr) {
      case 'Low':
        quality = CompressQuality.low;
        break;
      case 'High':
        quality = CompressQuality.high;
        break;
      default:
        quality = CompressQuality.medium;
    }

    // 分辨率设置：只设置targetHeight，让FFmpeg根据视频方向自动计算宽度
    // 720p 表示视频的短边为720像素
    int? targetHeight;
    switch (resolutionStr) {
      case '480P':
        targetHeight = 480;
        break;
      case '720P':
        targetHeight = 720;
        break;
      case '1080P':
        targetHeight = 1080;
        break;
      case 'Original':
        // 保持原始分辨率
        targetHeight = null;
        break;
      default:
        targetHeight = 1080;
    }

    final config = CompressConfig(
      quality: quality,
      targetHeight: targetHeight,
      targetWidth: null, // 不设置宽度，让FFmpeg自动计算
    );

    debugPrint(
        '[LocalCompressBloc] Loaded default config: quality=$qualityStr, resolution=$resolutionStr, targetHeight=$targetHeight');
    emit(state.copyWith(config: config));
  }

  /// 选择视频
  ///
  /// 从视频数据创建VideoInfo并添加到已选列表
  void _onSelectVideos(
    SelectVideos event,
    Emitter<LocalCompressState> emit,
  ) {
    debugPrint(
        '[LocalCompressBloc] Selecting videos: ${event.videoDataList.length}');

    final newVideos = <VideoInfo>[];
    for (final videoData in event.videoDataList) {
      final path = videoData['path'] as String;

      // 跳过已存在的视频
      if (state.selectedVideos.any((v) => v.path == path)) continue;

      final videoInfo = VideoInfo(
        path: path,
        name: videoData['name'] as String?,
        size: videoData['size'] as int?,
        width: videoData['width'] as int?,
        height: videoData['height'] as int?,
        duration: videoData['duration'] != null
            ? Duration(
                milliseconds: ((videoData['duration'] as num) * 1000).toInt())
            : null,
        thumbnailBytes: videoData['thumbnailBytes'] as Uint8List?,
        bitrate: videoData['bitrate'] as int?,
        frameRate: videoData['frameRate'] as double?,
      );
      newVideos.add(videoInfo);
    }

    // 追加新视频到现有列表
    final allVideos = [...state.selectedVideos, ...newVideos];

    debugPrint(
        '[LocalCompressBloc] Total ${allVideos.length} videos (${newVideos.length} new)');
    emit(state.copyWith(selectedVideos: allVideos));
  }

  /// 移除已选视频
  ///
  /// 同时清理相关的压缩任务和订阅
  void _onRemoveSelectedVideo(
    RemoveSelectedVideo event,
    Emitter<LocalCompressState> emit,
  ) {
    // 从已选列表移除
    final updatedVideos =
        state.selectedVideos.where((v) => v.path != event.path).toList();

    // 查找并移除相关任务
    final relatedTask =
        state.tasks.where((t) => t.video.path == event.path).firstOrNull;
    if (relatedTask != null) {
      // 取消订阅
      _subscriptions[relatedTask.id]?.cancel();
      _subscriptions.remove(relatedTask.id);
      // 取消FFmpeg任务
      if (relatedTask.isRunning) {
        _ffmpegService.cancelCompress(relatedTask.id);
        _runningTasks--;
      }
      // 从队列中移除
      _pendingQueue.removeWhere((id) => id == relatedTask.id);
    }

    // 从任务列表移除
    final updatedTasks =
        state.tasks.where((t) => t.video.path != event.path).toList();

    // 检查是否还有压缩中的任务
    final stillCompressing = updatedTasks.any((t) => t.isRunning || t.isQueued);

    emit(state.copyWith(
      selectedVideos: updatedVideos,
      tasks: updatedTasks,
      isCompressing: stillCompressing,
    ));

    // 如果释放了槽位，处理队列
    if (relatedTask != null &&
        relatedTask.isRunning &&
        _pendingQueue.isNotEmpty) {
      add(const _ProcessQueue());
    }
  }

  /// 更新压缩配置
  void _onUpdateConfig(
    UpdateCompressConfig event,
    Emitter<LocalCompressState> emit,
  ) {
    emit(state.copyWith(config: event.config));
  }

  /// 开始压缩任务
  ///
  /// 创建压缩任务并加入队列处理
  Future<void> _onStartCompress(
    StartCompress event,
    Emitter<LocalCompressState> emit,
  ) async {
    if (!state.hasVideos) return;

    // 重新读取最新的设置
    final qualityStr = _storageService.getDefaultQuality();
    final resolutionStr = _storageService.getDefaultResolution();

    CompressQuality quality = CompressQuality.medium;
    switch (qualityStr) {
      case 'Low':
        quality = CompressQuality.low;
        break;
      case 'High':
        quality = CompressQuality.high;
        break;
      default:
        quality = CompressQuality.medium;
    }

    int? targetHeight;
    switch (resolutionStr) {
      case '480P':
        targetHeight = 480;
        break;
      case '720P':
        targetHeight = 720;
        break;
      case '1080P':
        targetHeight = 1080;
        break;
      case 'Original':
        targetHeight = null;
        break;
      default:
        targetHeight = 1080;
    }

    // 使用最新的配置
    final latestConfig = CompressConfig(
      quality: quality,
      targetHeight: targetHeight,
      targetWidth: null,
    );

    debugPrint(
        '[LocalCompressBloc] Starting compress for ${state.selectedVideos.length} videos');
    debugPrint(
        '[LocalCompressBloc] Using config: quality=$qualityStr, resolution=$resolutionStr, targetHeight=$targetHeight');

    // 只为没有 task 的视频创建新任务
    final videosWithoutTask = state.selectedVideos
        .where((video) => !state.tasks.any((t) => t.video.path == video.path))
        .toList();

    if (videosWithoutTask.isEmpty) {
      debugPrint('[LocalCompressBloc] No new videos to compress');
      return;
    }

    final newTasks = <CompressTask>[];
    final targetBitrate = latestConfig.bitrate;

    for (final video in videosWithoutTask) {
      // 检查是否应该跳过
      final skipReason = _checkSkipReason(
        video: video,
        targetHeight: targetHeight,
        targetBitrate: targetBitrate,
        targetBitrateLabel: latestConfig.qualityLabel,
      );

      if (skipReason != null) {
        // 创建跳过的任务
        newTasks.add(CompressTask(
          id: _uuid.v4(),
          video: video,
          config: latestConfig,
          status: CompressTaskStatus.skipped,
          skipReason: skipReason,
        ));
        debugPrint('[LocalCompressBloc] Skipped ${video.name}: $skipReason');
      } else {
        // 创建正常任务
        newTasks.add(CompressTask(
          id: _uuid.v4(),
          video: video,
          config: latestConfig,
          status: CompressTaskStatus.queued,
        ));
      }
    }

    final allTasks = [...state.tasks, ...newTasks];

    // 检查是否有需要压缩的任务（非跳过）
    final hasCompressTasks = newTasks.any((t) => !t.isSkipped);

    // iOS 提示用户保持前台
    String? toastMessage;
    if (hasCompressTasks && Platform.isIOS) {
      toastMessage = 'Please keep the app in foreground during compression';
    }

    emit(
      state.copyWith(
        tasks: allTasks,
        isCompressing: hasCompressTasks,
        config: latestConfig,
        toastMessage: toastMessage,
      ),
    );

    // 将非跳过任务加入队列
    for (final task in newTasks.where((t) => !t.isSkipped)) {
      _pendingQueue.add(task.id);
    }

    debugPrint(
        '[LocalCompressBloc] Created ${newTasks.length} tasks (${newTasks.where((t) => t.isSkipped).length} skipped)');

    // 开始处理队列
    if (_pendingQueue.isNotEmpty) {
      add(const _ProcessQueue());
    }
  }

  /// 检查跳过原因
  ///
  /// 只有同时满足分辨率和画质条件才跳过
  /// 返回 null 表示不跳过，否则返回跳过原因
  String? _checkSkipReason({
    required VideoInfo video,
    required int? targetHeight,
    required int targetBitrate,
    required String targetBitrateLabel,
  }) {
    bool resolutionMet = false;
    bool qualityMet = false;
    String? resolutionDetail;
    String? qualityDetail;

    // 检查分辨率
    if (targetHeight != null && video.width != null && video.height != null) {
      final originalWidth = video.width!;
      final originalHeight = video.height!;

      // 短边是较小的那个维度
      final shortSide =
          originalWidth < originalHeight ? originalWidth : originalHeight;

      if (shortSide <= targetHeight) {
        resolutionMet = true;
        resolutionDetail = '${shortSide}p ≤ ${targetHeight}p';
      }
    } else {
      // 没有目标分辨率要求，视为满足
      resolutionMet = true;
    }

    // 检查比特率
    if (video.bitrate != null && video.bitrate! > 0 && targetBitrate > 0) {
      if (video.bitrate! <= targetBitrate) {
        qualityMet = true;
        final originalBitrateMbps =
            (video.bitrate! / 1000000).toStringAsFixed(1);
        final targetBitrateMbps = (targetBitrate / 1000000).toStringAsFixed(1);
        qualityDetail = '$originalBitrateMbps Mbps ≤ $targetBitrateMbps Mbps';
      }
    } else {
      // 无法获取比特率，视为满足
      qualityMet = true;
    }

    // 只有两者都满足才跳过
    if (resolutionMet && qualityMet) {
      final reasons = <String>[];
      if (resolutionDetail != null) {
        reasons.add('Resolution: $resolutionDetail');
      }
      if (qualityDetail != null) {
        reasons.add('Quality: $qualityDetail');
      }
      if (reasons.isEmpty) {
        return 'Already meets target settings';
      }
      return 'Skipped - ${reasons.join(', ')}';
    }

    return null;
  }

  /// 处理任务队列
  ///
  /// 控制同时运行的任务数量（最多2个并发）
  void _onProcessQueue(
    _ProcessQueue event,
    Emitter<LocalCompressState> emit,
  ) {
    while (_runningTasks < _maxConcurrentTasks && _pendingQueue.isNotEmpty) {
      final taskId = _pendingQueue.removeFirst();
      _runningTasks++;
      add(_StartTask(taskId: taskId));
    }
  }

  /// 启动单个任务
  void _onStartTask(
    _StartTask event,
    Emitter<LocalCompressState> emit,
  ) async {
    final index = state.tasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;

    final task = state.tasks[index];
    if (task.isRunning || task.isComplete) return;

    var tasks = List<CompressTask>.from(state.tasks);
    tasks[index] = task.copyWith(status: CompressTaskStatus.running);
    emit(state.copyWith(tasks: tasks));

    debugPrint(
        '[LocalCompressBloc] Starting task ${task.id} for ${task.video.path}');

    // 启动前台服务
    if (_foregroundService != null && Platform.isAndroid) {
      await _foregroundService!.startCompression(task.video.name ?? 'video');
    }

    // 生成输出路径
    final outputPath =
        await _getOutputPath(task.video.name ?? 'video_${task.id}.mp4');
    debugPrint('[LocalCompressBloc] Output path: $outputPath');

    // 启动压缩并订阅进度
    final stream = _ffmpegService.compressVideo(
      inputPath: task.video.path,
      outputPath: outputPath,
      bitrate: task.config.bitrate,
      width: task.config.targetWidth,
      height: task.config.targetHeight,
      taskId: task.id,
      originalWidth: task.video.width,
      originalHeight: task.video.height,
    );

    _subscriptions[task.id]?.cancel();
    _subscriptions[task.id] = stream.listen(
      (progress) {
        add(_UpdateTaskProgress(taskId: task.id, progress: progress));
      },
      onDone: () {
        add(_TaskCompleted(taskId: task.id, outputPath: outputPath));
      },
      onError: (error) {
        add(_TaskCompleted(taskId: task.id, error: error.toString()));
      },
    );
  }

  /// 获取输出文件路径
  ///
  /// macOS使用Downloads目录，iOS使用Documents目录
  Future<String> _getOutputPath(String originalName) async {
    Directory outputDir;

    if (Platform.isIOS) {
      outputDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      outputDir = downloadsDir ?? await getApplicationDocumentsDirectory();
    } else {
      outputDir = await getApplicationDocumentsDirectory();
    }

    final videoCompressDir = Directory('${outputDir.path}/compressed_videos');
    if (!await videoCompressDir.exists()) {
      await videoCompressDir.create(recursive: true);
    }

    final baseName = originalName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return '${videoCompressDir.path}/${baseName}_compressed.mp4';
  }

  /// 更新任务进度
  void _onUpdateTaskProgress(
    _UpdateTaskProgress event,
    Emitter<LocalCompressState> emit,
  ) {
    final index = state.tasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;

    final tasks = List<CompressTask>.from(state.tasks);
    tasks[index] = tasks[index].copyWith(progress: event.progress);
    emit(state.copyWith(tasks: tasks));

    // 更新前台服务通知
    if (_foregroundService != null && Platform.isAndroid) {
      final task = tasks[index];
      _foregroundService!.updateProgress(
        task.video.name ?? 'video',
        event.progress,
      );
    }
  }

  /// 任务完成处理
  ///
  /// 获取压缩后文件信息并保存历史记录
  Future<void> _onTaskCompleted(
    _TaskCompleted event,
    Emitter<LocalCompressState> emit,
  ) async {
    final index = state.tasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;

    _subscriptions[event.taskId]?.cancel();
    _subscriptions.remove(event.taskId);

    var tasks = List<CompressTask>.from(state.tasks);

    if (event.error != null) {
      // 失败
      tasks[index] = tasks[index].copyWith(
        status: CompressTaskStatus.failed,
        errorMessage: event.error,
      );
      emit(state.copyWith(tasks: tasks));
    } else {
      final outputPath = event.outputPath;
      if (outputPath == null || outputPath.isEmpty) {
        tasks[index] = tasks[index].copyWith(
          status: CompressTaskStatus.failed,
          errorMessage: 'Compression failed: output path is empty',
        );
        emit(state.copyWith(tasks: tasks));
      } else {
        int? compressedSize;
        int? compressedWidth;
        int? compressedHeight;

        try {
          final outputFile = File(outputPath);
          if (await outputFile.exists()) {
            compressedSize = await outputFile.length();
            debugPrint(
                '[LocalCompressBloc] Output file size: $compressedSize bytes');

            final outputInfo = await _ffmpegService.getVideoInfo(outputPath);
            compressedWidth = outputInfo['width'] as int?;
            compressedHeight = outputInfo['height'] as int?;
            debugPrint(
                '[LocalCompressBloc] Output resolution: ${compressedWidth}x$compressedHeight');
          } else {
            debugPrint(
                '[LocalCompressBloc] Output file does not exist: $outputPath');
          }
        } catch (e) {
          debugPrint('[LocalCompressBloc] Failed to get file info: $e');
        }

        if (compressedSize == null || compressedSize == 0) {
          tasks[index] = tasks[index].copyWith(
            status: CompressTaskStatus.failed,
            errorMessage: 'Compression failed: output file is empty',
          );
          emit(state.copyWith(tasks: tasks));
        } else {
          // 成功完成
          tasks[index] = tasks[index].copyWith(
            status: CompressTaskStatus.completed,
            outputPath: outputPath,
            progress: 1.0,
            compressedSize: compressedSize,
            compressedWidth: compressedWidth,
            compressedHeight: compressedHeight,
          );
          emit(state.copyWith(tasks: tasks));

          // 保存历史记录
          final task = state.tasks[index];
          await _storageService.saveHistoryItem({
            'id': task.id,
            'name': task.video.name ?? 'Unknown',
            'originalSize': task.video.size ?? 0,
            'compressedSize': compressedSize,
            'compressedAt': DateTime.now().toIso8601String(),
            'outputPath': outputPath,
            'originalResolution': task.video.resolution,
            'compressedResolution':
                compressedWidth != null && compressedHeight != null
                    ? '${compressedWidth}x$compressedHeight'
                    : '',
            'duration': task.video.duration?.inSeconds.toDouble() ?? 0,
            'originalBitrate': task.video.bitrate ?? 0,
            'compressedBitrate': task.config.bitrate,
            'frameRate': task.video.frameRate ?? 0,
          });
        }
      }
    }

    // 保存任务列表
    await _saveTasks();

    // 检查是否还有运行中的任务
    final hasRunning =
        tasks.any((t) => t.isRunning || t.isPending || t.isQueued);
    if (!hasRunning) {
      emit(state.copyWith(isCompressing: false));

      // 所有任务完成，停止前台服务
      if (_foregroundService != null && Platform.isAndroid) {
        await _foregroundService!.stopCompression();
      }
    }

    _runningTasks--;
    if (_pendingQueue.isNotEmpty) {
      add(const _ProcessQueue());
    }
  }

  /// 取消压缩任务
  void _onCancelCompress(
    CancelCompress event,
    Emitter<LocalCompressState> emit,
  ) async {
    final index = state.tasks.indexWhere((t) => t.id == event.taskId);
    if (index != -1) {
      final task = state.tasks[index];
      _subscriptions[event.taskId]?.cancel();
      _subscriptions.remove(event.taskId);
      _ffmpegService.cancelCompress(event.taskId);
      final tasks = List<CompressTask>.from(state.tasks);
      tasks[index] = tasks[index].copyWith(
        status: CompressTaskStatus.cancelled,
      );
      emit(state.copyWith(tasks: tasks));

      if (task.isRunning) {
        _runningTasks--;

        // 完成前台服务任务
        if (_foregroundService != null && Platform.isAndroid) {
          await _foregroundService!.completeTask();
        }

        if (_pendingQueue.isNotEmpty) {
          add(const _ProcessQueue());
        }
      }
    }
  }

  /// 移除任务
  Future<void> _onRemoveTask(
      RemoveTask event, Emitter<LocalCompressState> emit) async {
    _subscriptions[event.taskId]?.cancel();
    _subscriptions.remove(event.taskId);
    _pendingQueue.removeWhere((id) => id == event.taskId);
    final tasks = state.tasks.where((t) => t.id != event.taskId).toList();
    emit(state.copyWith(tasks: tasks));

    // 删除持久化数据
    await _storageService.deleteTaskItem(event.taskId);
  }

  /// 清除已完成任务
  void _onClearCompleted(
    ClearCompleted event,
    Emitter<LocalCompressState> emit,
  ) {
    final tasks = state.tasks
        .where((t) => !t.isComplete && !t.isFailed && !t.isSkipped)
        .toList();
    emit(state.copyWith(tasks: tasks));
  }

  /// 检查运行中的任务（应用恢复时调用）
  ///
  /// 验证运行中的任务是否实际已完成（处理后台回调丢失的情况）
  /// iOS 后台会暂停任务，直接标记为中断
  Future<void> _onCheckRunningTasks(
    CheckRunningTasks event,
    Emitter<LocalCompressState> emit,
  ) async {
    final runningTasks = state.tasks.where((t) => t.isRunning).toList();

    if (runningTasks.isEmpty) return;

    debugPrint(
        '[LocalCompressBloc] Checking ${runningTasks.length} running tasks on resume');

    // iOS 直接标记所有运行中的任务为中断
    if (Platform.isIOS) {
      String? toastMessage;
      for (final task in runningTasks) {
        // 清理 FFmpeg 任务状态
        _ffmpegService.removeTask(task.id);
        _subscriptions[task.id]?.cancel();
        _subscriptions.remove(task.id);

        // 删除不完整的输出文件
        final outputPath =
            await _getOutputPath(task.video.name ?? 'video_${task.id}.mp4');
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          try {
            await outputFile.delete();
          } catch (e) {
            debugPrint(
                '[LocalCompressBloc] Failed to delete incomplete file: $e');
          }
        }

        debugPrint(
            '[LocalCompressBloc] iOS: Task ${task.id} interrupted, marking as failed');
        add(_TaskCompleted(
          taskId: task.id,
          error: 'Compression interrupted. Please try again.',
        ));
        toastMessage = 'Compression interrupted. Please try again.';
      }

      // 提示用户
      if (toastMessage != null) {
        emit(state.copyWith(toastMessage: toastMessage));
      }
      return;
    }

    // Android: 检查 session 状态
    for (final task in runningTasks) {
      final sessionId = _ffmpegService.getTaskSessionId(task.id);
      final outputPath =
          await _getOutputPath(task.video.name ?? 'video_${task.id}.mp4');
      final outputFile = File(outputPath);

      // 检查FFmpeg session是否真的还在运行
      final isSessionActive = await _ffmpegService.isSessionActive(sessionId);

      if (isSessionActive) {
        debugPrint('[LocalCompressBloc] Task ${task.id} session still active');
        if (await outputFile.exists()) {
          final size = await outputFile.length();
          debugPrint(
              '[LocalCompressBloc] Task ${task.id} output size: $size bytes');
        }
        continue;
      }

      // Session已结束，从映射中移除
      _ffmpegService.removeTask(task.id);
      debugPrint('[LocalCompressBloc] Task ${task.id} session ended');

      // 检查输出文件
      if (await outputFile.exists()) {
        final compressedSize = await outputFile.length();
        debugPrint(
            '[LocalCompressBloc] Found output file for task ${task.id}: $compressedSize bytes');

        if (compressedSize > 0) {
          final isValid = await _ffmpegService.isVideoValid(outputPath);

          if (isValid) {
            debugPrint(
                '[LocalCompressBloc] Task ${task.id} output is valid, triggering completion');
            add(_TaskCompleted(
              taskId: task.id,
              outputPath: outputPath,
            ));
          } else {
            debugPrint(
                '[LocalCompressBloc] Task ${task.id} file invalid, marking as failed');
            try {
              await outputFile.delete();
            } catch (e) {
              debugPrint(
                  '[LocalCompressBloc] Failed to delete incomplete file: $e');
            }
            add(_TaskCompleted(
              taskId: task.id,
              error: 'Compression interrupted. Please try again.',
            ));
          }
        } else {
          add(_TaskCompleted(
            taskId: task.id,
            error: 'Compression failed: output file is empty',
          ));
        }
      } else {
        debugPrint(
            '[LocalCompressBloc] Output file not found for task ${task.id}, marking as failed');
        add(_TaskCompleted(
          taskId: task.id,
          error: 'Compression interrupted. Please try again.',
        ));
      }
    }
  }

  /// 清除 Toast 消息
  void _onClearToastMessage(
    ClearToastMessage event,
    Emitter<LocalCompressState> emit,
  ) {
    emit(state.copyWith(clearToastMessage: true));
  }

  /// 加载已保存的任务
  ///
  /// 从本地存储恢复未完成的任务
  Future<void> _onLoadSavedTasks(
    LoadSavedTasks event,
    Emitter<LocalCompressState> emit,
  ) async {
    try {
      final taskDataList = await _storageService.getTaskList();
      if (taskDataList.isEmpty) return;

      final loadedTasks = <CompressTask>[];
      final loadedVideos = <VideoInfo>[];

      for (final taskData in taskDataList) {
        try {
          final task = CompressTask.fromJson(taskData);
          // 只恢复已完成、失败或跳过的任务
          // 运行中的任务在应用重启后需要重新处理
          if (task.isComplete || task.isFailed || task.isSkipped) {
            loadedTasks.add(task);
            if (!loadedVideos.any((v) => v.path == task.video.path)) {
              loadedVideos.add(task.video);
            }
          }
        } catch (e) {
          debugPrint('[LocalCompressBloc] Failed to load task: $e');
        }
      }

      if (loadedTasks.isNotEmpty) {
        debugPrint(
            '[LocalCompressBloc] Loaded ${loadedTasks.length} saved tasks');
        emit(state.copyWith(
          tasks: loadedTasks,
          selectedVideos: loadedVideos,
        ));
      }
    } catch (e) {
      debugPrint('[LocalCompressBloc] Failed to load saved tasks: $e');
    }
  }

  /// 保存任务列表到本地存储
  Future<void> _saveTasks() async {
    try {
      final taskDataList = state.tasks.map((t) => t.toJson()).toList();
      await _storageService.saveTaskList(taskDataList);
    } catch (e) {
      debugPrint('[LocalCompressBloc] Failed to save tasks: $e');
    }
  }

  /// 重试任务
  ///
  /// 将失败或跳过的任务重新加入队列
  void _onRetryTask(
    RetryTask event,
    Emitter<LocalCompressState> emit,
  ) {
    final index = state.tasks.indexWhere((t) => t.id == event.taskId);
    if (index == -1) return;

    final task = state.tasks[index];

    // 只有失败或跳过的任务可以重试
    if (!task.isFailed && !task.isSkipped) return;

    debugPrint('[LocalCompressBloc] Retrying task ${task.id}');

    // 重置任务状态
    final tasks = List<CompressTask>.from(state.tasks);
    tasks[index] = task.copyWith(
      status: CompressTaskStatus.queued,
      progress: 0.0,
      outputPath: null,
      compressedSize: null,
      compressedWidth: null,
      compressedHeight: null,
      errorMessage: null,
      skipReason: null,
    );

    emit(state.copyWith(
      tasks: tasks,
      isCompressing: true,
    ));

    // 加入队列
    _pendingQueue.add(task.id);
    add(const _ProcessQueue());
  }

  @override
  Future<void> close() async {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _pendingQueue.clear();

    // 停止前台服务
    if (_foregroundService != null && Platform.isAndroid) {
      await _foregroundService!.stopCompression();
    }

    return super.close();
  }
}

// 内部事件类（不对外暴露）

/// 启动任务内部事件
class _StartTask extends LocalCompressEvent {
  final String taskId;

  const _StartTask({required this.taskId});
}

/// 处理队列内部事件
class _ProcessQueue extends LocalCompressEvent {
  const _ProcessQueue();
}

/// 更新任务进度内部事件
class _UpdateTaskProgress extends LocalCompressEvent {
  final String taskId;
  final double progress;

  const _UpdateTaskProgress({required this.taskId, required this.progress});
}

/// 任务完成内部事件
class _TaskCompleted extends LocalCompressEvent {
  final String taskId;
  final String? outputPath;
  final String? error;

  const _TaskCompleted({required this.taskId, this.outputPath, this.error});
}
