/// 设置功能BLoC实现
///
/// 该文件包含事件定义和BLoC，用于管理应用程序设置，包括质量预设、分辨率默认值和缓存管理。
library;

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/storage_service.dart';
import 'settings_state.dart';

/// 所有设置相关事件的基类
abstract class SettingsEvent {}

/// 从持久化存储加载所有设置的事件
class LoadSettings extends SettingsEvent {}

/// 更新默认压缩质量的事件
///
/// [quality] - 新的质量预设（'Low', 'Medium', 'High'）
class SetDefaultQuality extends SettingsEvent {
  final String quality;
  SetDefaultQuality(this.quality);
}

/// 更新默认输出分辨率的事件
///
/// [resolution] - 新的分辨率（'480P', '720P', '1080P', 'Original'）
class SetDefaultResolution extends SettingsEvent {
  final String resolution;
  SetDefaultResolution(this.resolution);
}

/// 清除应用程序缓存的事件
class ClearCache extends SettingsEvent {}

/// 负责管理应用程序设置状态的BLoC
///
/// 处理以下操作：
/// - 从持久化存储加载设置
/// - 更新默认质量和分辨率首选项
/// - 清除应用程序缓存
/// - 计算缓存大小
///
/// 使用 [StorageService] 进行持久化设置存储
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// 持久化存储操作服务
  final StorageService _storageService;

  /// 使用所需的依赖创建新的 [SettingsBloc]
  ///
  /// [storageService] - 用于读写设置数据的服务
  SettingsBloc({required StorageService storageService})
      : _storageService = storageService,
        super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<SetDefaultQuality>(_onSetDefaultQuality);
    on<SetDefaultResolution>(_onSetDefaultResolution);
    on<ClearCache>(_onClearCache);
  }

  /// 处理 [LoadSettings] 事件
  ///
  /// 从存储加载所有设置，包括：
  /// - 输出目录路径
  /// - 当前缓存大小
  /// - 默认质量首选项
  /// - 默认分辨率首选项
  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final outputDir = await _storageService.getOutputDirectory();
    final cacheSize = await _getCacheSize();
    final quality = _storageService.getDefaultQuality();
    final resolution = _storageService.getDefaultResolution();
    emit(state.copyWith(
      outputDirectory: outputDir,
      cacheSize: cacheSize,
      defaultQuality: quality,
      defaultResolution: resolution,
    ));
  }

  /// 处理 [SetDefaultQuality] 事件
  ///
  /// 将新的质量首选项保存到存储并更新状态
  Future<void> _onSetDefaultQuality(
    SetDefaultQuality event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.setDefaultQuality(event.quality);
    emit(state.copyWith(defaultQuality: event.quality));
  }

  /// 处理 [SetDefaultResolution] 事件
  ///
  /// 将新的分辨率首选项保存到存储并更新状态
  Future<void> _onSetDefaultResolution(
    SetDefaultResolution event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.setDefaultResolution(event.resolution);
    emit(state.copyWith(defaultResolution: event.resolution));
  }

  /// 处理 [ClearCache] 事件
  ///
  /// 清除缓存目录并重置状态中的缓存大小
  Future<void> _onClearCache(
    ClearCache event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.clearCache();
    emit(state.copyWith(cacheSize: 0));
  }

  /// 计算缓存目录的总大小
  ///
  /// 递归遍历临时目录中的所有文件并累加它们的大小。如果目录不存在或发生任何错误，则返回0。
  ///
  /// 返回缓存大小（以字节为单位）
  Future<int> _getCacheSize() async {
    int size = 0;
    try {
      final tempDir = await _storageService.getTempDirectory();
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return size;
  }
}
