/// 首页事件定义
///
/// 定义首页BLoC支持的事件类型
import 'package:equatable/equatable.dart';

/// 首页事件基类
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// 标签切换事件
///
/// [index] - 目标标签索引
/// - 0: 压缩页面
/// - 1: 历史页面
/// - 2: 设置页面
class HomeTabChanged extends HomeEvent {
  final int index;

  const HomeTabChanged(this.index);

  @override
  List<Object?> get props => [index];
}
