/// 本地压缩状态定义
///
/// 存储压缩功能的所有状态数据
import 'package:equatable/equatable.dart';
import '../../../data/models/video_info.dart';
import '../../../data/models/compress_task.dart';
import '../../../data/models/compress_config.dart';

/// 本地压缩状态类
class LocalCompressState extends Equatable {
  /// 已选择的视频列表
  final List<VideoInfo> selectedVideos;

  /// 当前压缩配置
  final CompressConfig config;

  /// 压缩任务列表
  final List<CompressTask> tasks;

  /// 是否正在压缩中
  final bool isCompressing;

  /// 是否正在加载视频信息
  final bool isLoadingVideos;

  /// 错误信息
  final String? errorMessage;

  const LocalCompressState({
    this.selectedVideos = const [],
    this.config = const CompressConfig(),
    this.tasks = const [],
    this.isCompressing = false,
    this.isLoadingVideos = false,
    this.errorMessage,
  });

  /// 是否有已选视频
  bool get hasVideos => selectedVideos.isNotEmpty;

  /// 等待中的任务数量
  int get pendingCount => tasks.where((t) => t.isPending).length;

  /// 运行中的任务数量
  int get runningCount => tasks.where((t) => t.isRunning).length;

  /// 已完成的任务数量
  int get completedCount => tasks.where((t) => t.isComplete).length;

  /// 失败的任务数量
  int get failedCount => tasks.where((t) => t.isFailed).length;

  /// 复制并修改部分属性
  LocalCompressState copyWith({
    List<VideoInfo>? selectedVideos,
    CompressConfig? config,
    List<CompressTask>? tasks,
    bool? isCompressing,
    bool? isLoadingVideos,
    String? errorMessage,
  }) {
    return LocalCompressState(
      selectedVideos: selectedVideos ?? this.selectedVideos,
      config: config ?? this.config,
      tasks: tasks ?? this.tasks,
      isCompressing: isCompressing ?? this.isCompressing,
      isLoadingVideos: isLoadingVideos ?? this.isLoadingVideos,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        selectedVideos,
        config,
        tasks,
        isCompressing,
        isLoadingVideos,
        errorMessage,
      ];
}
