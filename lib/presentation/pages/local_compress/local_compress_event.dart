/// 本地压缩事件定义
///
/// 定义压缩功能相关的所有事件
import 'package:equatable/equatable.dart';

/// 压缩事件基类
abstract class LocalCompressEvent extends Equatable {
  const LocalCompressEvent();

  @override
  List<Object?> get props => [];
}

/// 加载默认配置事件
///
/// 从本地存储读取用户设置的默认画质和分辨率
class LoadDefaultConfig extends LocalCompressEvent {
  const LoadDefaultConfig();
}

/// 选择视频事件
///
/// [videoDataList] - 视频数据列表，每个元素包含：
/// - path: 视频文件路径
/// - thumbnailBytes: 缩略图数据（可选）
class SelectVideos extends LocalCompressEvent {
  final List<Map<String, dynamic>> videoDataList;

  const SelectVideos(this.videoDataList);

  @override
  List<Object?> get props => [videoDataList];
}

/// 更新压缩配置事件
///
/// [config] - 新的压缩配置（CompressConfig）
class UpdateCompressConfig extends LocalCompressEvent {
  final dynamic config;

  const UpdateCompressConfig(this.config);

  @override
  List<Object?> get props => [config];
}

/// 开始压缩事件
///
/// 为所有未压缩的视频创建压缩任务
class StartCompress extends LocalCompressEvent {
  const StartCompress();
}

/// 取消压缩事件
///
/// [taskId] - 要取消的任务ID
class CancelCompress extends LocalCompressEvent {
  final String taskId;

  const CancelCompress(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 移除任务事件
///
/// 从任务列表中移除指定任务
class RemoveTask extends LocalCompressEvent {
  final String taskId;

  const RemoveTask(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 清除已完成任务事件
///
/// 清除所有已完成和失败的任务
class ClearCompleted extends LocalCompressEvent {
  const ClearCompleted();
}

/// 移除已选视频事件
///
/// [path] - 要移除的视频路径
class RemoveSelectedVideo extends LocalCompressEvent {
  final String path;

  const RemoveSelectedVideo(this.path);

  @override
  List<Object?> get props => [path];
}

/// 检查运行中的任务事件
///
/// 用于应用恢复时检查是否有任务已完成但回调未触发
class CheckRunningTasks extends LocalCompressEvent {
  const CheckRunningTasks();
}

/// 清除 Toast 消息事件
///
/// UI 显示完 Toast 后调用此事件清除消息
class ClearToastMessage extends LocalCompressEvent {
  const ClearToastMessage();
}
