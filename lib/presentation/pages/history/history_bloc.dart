/// 历史记录功能 BLoC 实现
///
/// 包含管理压缩历史功能的事件定义和 BLoC。
/// 处理历史记录的加载、添加、删除和清空操作。
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/storage_service.dart';
import 'history_state.dart';

/// 历史记录相关事件的基类
abstract class HistoryEvent {}

/// 从存储加载所有历史记录的事件
class LoadHistory extends HistoryEvent {}

/// 清空所有历史记录的事件
class ClearHistory extends HistoryEvent {}

/// 根据 ID 删除单条历史记录的事件
///
/// [id] - 要删除的历史记录的唯一标识符
class DeleteHistoryItem extends HistoryEvent {
  final String id;
  DeleteHistoryItem(this.id);
}

/// 添加新历史记录的事件
///
/// [item] - 要添加到历史列表的 [HistoryItem]
class AddHistoryItem extends HistoryEvent {
  final HistoryItem item;
  AddHistoryItem(this.item);
}

/// 负责管理压缩历史状态的 BLoC
///
/// 处理以下操作：
/// - 从持久化存储加载历史记录
/// - 压缩完成后添加新的历史条目
/// - 删除单个历史条目
/// - 清空所有历史条目
///
/// 使用 [StorageService] 进行持久化数据存储。
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  /// 持久化存储操作服务
  final StorageService _storageService;

  /// 创建新的 [HistoryBloc]，使用所需的依赖
  ///
  /// [storageService] - 用于读/写历史数据的服务
  HistoryBloc({required StorageService storageService})
      : _storageService = storageService,
        super(const HistoryState()) {
    on<LoadHistory>(_onLoadHistory);
    on<ClearHistory>(_onClearHistory);
    on<DeleteHistoryItem>(_onDeleteItem);
    on<AddHistoryItem>(_onAddItem);
  }

  /// 处理 [LoadHistory] 事件
  ///
  /// 从存储加载所有历史记录并转换为 [HistoryItem] 对象。
  /// 使用加载的记录更新状态。
  Future<void> _onLoadHistory(
    LoadHistory event,
    Emitter<HistoryState> emit,
  ) async {
    final list = await _storageService.getHistoryList();
    final items = list
        .map((json) => HistoryItem(
              id: json['id'] ?? '',
              name: json['name'] ?? '',
              originalSize: json['originalSize'] ?? 0,
              compressedSize: json['compressedSize'] ?? 0,
              compressedAt: json['compressedAt'] != null
                  ? DateTime.parse(json['compressedAt'])
                  : DateTime.now(),
              outputPath: json['outputPath'] ?? '',
              originalResolution: json['originalResolution'] ?? '',
              compressedResolution: json['compressedResolution'] ?? '',
              duration: (json['duration'] as num?)?.toDouble() ?? 0,
              originalBitrate: (json['originalBitrate'] as num?)?.toInt() ?? 0,
              compressedBitrate:
                  (json['compressedBitrate'] as num?)?.toInt() ?? 0,
              frameRate: (json['frameRate'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    emit(state.copyWith(items: items));
  }

  /// 处理 [ClearHistory] 事件
  ///
  /// 从存储中删除所有历史记录并清空状态。
  Future<void> _onClearHistory(
    ClearHistory event,
    Emitter<HistoryState> emit,
  ) async {
    await _storageService.clearHistory();
    emit(state.copyWith(items: []));
  }

  /// 处理 [DeleteHistoryItem] 事件
  ///
  /// 从存储中删除单条历史记录并更新状态。
  Future<void> _onDeleteItem(
    DeleteHistoryItem event,
    Emitter<HistoryState> emit,
  ) async {
    await _storageService.deleteHistoryItem(event.id);
    final items = state.items.where((item) => item.id != event.id).toList();
    emit(state.copyWith(items: items));
  }

  /// 处理 [AddHistoryItem] 事件
  ///
  /// 将新的历史记录保存到存储并添加到状态中。
  /// 新记录添加到列表开头（最新的在前）。
  Future<void> _onAddItem(
    AddHistoryItem event,
    Emitter<HistoryState> emit,
  ) async {
    await _storageService.saveHistoryItem({
      'id': event.item.id,
      'name': event.item.name,
      'originalSize': event.item.originalSize,
      'compressedSize': event.item.compressedSize,
      'compressedAt': event.item.compressedAt.toIso8601String(),
      'outputPath': event.item.outputPath,
      'originalResolution': event.item.originalResolution,
      'compressedResolution': event.item.compressedResolution,
      'duration': event.item.duration,
      'originalBitrate': event.item.originalBitrate,
      'compressedBitrate': event.item.compressedBitrate,
      'frameRate': event.item.frameRate,
    });
    final items = [event.item, ...state.items];
    emit(state.copyWith(items: items));
  }
}
